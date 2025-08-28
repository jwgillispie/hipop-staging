import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import '../../models/managed_vendor.dart';
import '../../services/managed_vendor_service.dart';
import '../../../shared/services/user_profile_service.dart';
import '../../../shared/models/user_profile.dart';
import '../../services/vendor_contact_service.dart';

class VendorFormDialog extends StatefulWidget {
  final String marketId;
  final String organizerId;
  final ManagedVendor? vendor; // null for create, populated for edit

  const VendorFormDialog({
    super.key,
    required this.marketId,
    required this.organizerId,
    this.vendor,
  });

  @override
  State<VendorFormDialog> createState() => _VendorFormDialogState();
}

class _VendorFormDialogState extends State<VendorFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  final UserProfileService _userProfileService = UserProfileService();
  final VendorContactService _contactService = VendorContactService();
  
  bool get isEditing => widget.vendor != null;
  bool _isLoading = false;
  int _currentPage = 0;
  UserProfile? _linkedUserProfile;
  String? _userSearchEmail;
  
  // Form controllers
  final _businessNameController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _zipController = TextEditingController();
  final _deliveryNotesController = TextEditingController();
  final _priceRangeController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _boothPreferencesController = TextEditingController();
  final _specialRequirementsController = TextEditingController();
  final _storyController = TextEditingController();
  final _sloganController = TextEditingController();
  final _specificProductsController = TextEditingController();
  
  // Form state
  List<VendorCategory> _selectedCategories = [];
  List<String> _products = [];
  List<String> _specialties = [];
  List<String> _operatingDays = [];
  List<String> _tags = [];
  List<String> _ccEmails = [];
  bool _canDeliver = false;
  bool _acceptsOrders = false;
  bool _isOrganic = false;
  bool _isLocallySourced = false;
  bool _isActive = true;
  bool _isFeatured = false;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadVendorData();
    }
  }

  Future<void> _loadLinkedUserProfile(String? userProfileId) async {
    if (userProfileId == null) return;
    
    try {
      _linkedUserProfile = await _userProfileService.getUserProfile(userProfileId);
      if (mounted) {
        setState(() {});
        _populateContactFromProfile();
      }
    } catch (e) {
      debugPrint('Error loading linked user profile: $e');
    }
  }

  void _populateContactFromProfile() {
    if (_linkedUserProfile == null) return;

    // Auto-populate contact fields from user profile
    _emailController.text = _linkedUserProfile!.email;
    if (_linkedUserProfile!.phoneNumber?.isNotEmpty == true) {
      _phoneController.text = _linkedUserProfile!.phoneNumber!;
    }
    if (_linkedUserProfile!.website?.isNotEmpty == true) {
      _websiteController.text = _linkedUserProfile!.website!;
    }
    if (_linkedUserProfile!.instagramHandle?.isNotEmpty == true) {
      _instagramController.text = _linkedUserProfile!.instagramHandle!;
    }
  }

  Future<void> _searchUserByEmail() async {
    if (_userSearchEmail?.isEmpty != false) return;

    setState(() => _isLoading = true);
    
    try {
      // Search for user by email using Firestore query
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user_profiles')
          .where('email', isEqualTo: _userSearchEmail!.toLowerCase().trim())
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty && mounted) {
        final doc = querySnapshot.docs.first;
        final userProfile = UserProfile.fromFirestore(doc);
        
        setState(() {
          _linkedUserProfile = userProfile;
        });
        _populateContactFromProfile();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User profile linked: ${userProfile.displayName}'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
      } else if (mounted) {
        // No user found with that email
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No user found with email: $_userSearchEmail'),
            backgroundColor: HiPopColors.warningAmber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching for user: $e'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadVendorData() {
    final vendor = widget.vendor!;
    _businessNameController.text = vendor.businessName;
    _vendorNameController.text = vendor.vendorName ?? '';
    _contactNameController.text = vendor.contactName;
    _descriptionController.text = vendor.description;
    
    // Load linked user profile if available
    if (vendor.userProfileId != null) {
      _loadLinkedUserProfile(vendor.userProfileId);
    } else {
      // Use local contact data if no profile linked
      _emailController.text = vendor.email ?? '';
      _phoneController.text = vendor.phoneNumber ?? '';
      _websiteController.text = vendor.website ?? '';
      _instagramController.text = vendor.instagramHandle ?? '';
    }
    
    _facebookController.text = vendor.facebookHandle ?? '';
    _addressController.text = vendor.address ?? '';
    _cityController.text = vendor.city ?? '';
    _stateController.text = vendor.state ?? '';
    _zipController.text = vendor.zipCode ?? '';
    _deliveryNotesController.text = vendor.deliveryNotes ?? '';
    _priceRangeController.text = vendor.priceRange ?? '';
    _certificationsController.text = vendor.certifications ?? '';
    _boothPreferencesController.text = vendor.boothPreferences ?? '';
    _specialRequirementsController.text = vendor.specialRequirements ?? '';
    _storyController.text = vendor.story ?? '';
    _sloganController.text = vendor.slogan ?? '';
    _specificProductsController.text = vendor.specificProducts ?? '';
    
    _selectedCategories = List.from(vendor.categories);
    _products = List.from(vendor.products);
    _specialties = List.from(vendor.specialties);
    _operatingDays = List.from(vendor.operatingDays);
    _tags = List.from(vendor.tags);
    _ccEmails = List.from(vendor.ccEmails);
    _canDeliver = vendor.canDeliver;
    _acceptsOrders = vendor.acceptsOrders;
    _isOrganic = vendor.isOrganic;
    _isLocallySourced = vendor.isLocallySourced;
    _isActive = vendor.isActive;
    _isFeatured = vendor.isFeatured;
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _vendorNameController.dispose();
    _contactNameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    _deliveryNotesController.dispose();
    _priceRangeController.dispose();
    _certificationsController.dispose();
    _boothPreferencesController.dispose();
    _specialRequirementsController.dispose();
    _storyController.dispose();
    _sloganController.dispose();
    _specificProductsController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildProgressIndicator(),
            const SizedBox(height: 24),
            Expanded(child: _buildFormPages()),
            const SizedBox(height: 24),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.store_mall_directory,
          color: Colors.indigo[600],
          size: 28,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEditing ? 'Edit Vendor' : 'Create New Vendor',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                isEditing ? 'Update vendor information' : 'Add a vendor to your market',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: List.generate(4, (index) {
        final isActive = index <= _currentPage;
        
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Colors.indigo : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFormPages() {
    return Form(
      key: _formKey,
      child: PageView(
        controller: _pageController,
        onPageChanged: (page) {
          setState(() {
            _currentPage = page;
          });
        },
        children: [
          _buildBasicInfoPage(),
          _buildContactLocationPage(),
          _buildProductsServicesPage(),
          _buildAdditionalInfoPage(),
        ],
      ),
    );
  }

  Widget _buildBasicInfoPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Business name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _vendorNameController,
            decoration: const InputDecoration(
              labelText: 'Vendor Name',
              border: OutlineInputBorder(),
              hintText: 'Individual vendor name (if different from business)',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _contactNameController,
            decoration: const InputDecoration(
              labelText: 'Contact Person *',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Contact person is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              border: OutlineInputBorder(),
              hintText: 'Brief description of the vendor',
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _sloganController,
            decoration: const InputDecoration(
              labelText: 'Business Slogan',
              border: OutlineInputBorder(),
              hintText: 'Optional tagline or motto',
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Categories',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VendorCategory.values.map((category) {
              final isSelected = _selectedCategories.contains(category);
              return FilterChip(
                label: Text(category.displayName),
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
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() {
                              _isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Featured',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: _isFeatured,
                          onChanged: (value) {
                            setState(() {
                              _isFeatured = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileLinkSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link to Vendor Account',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_linkedUserProfile != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Linked to: ${_linkedUserProfile!.displayTitle}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            _linkedUserProfile!.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Contact info will be auto-populated from their profile',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _linkedUserProfile = null;
                        });
                        // Clear the auto-populated fields
                        _emailController.clear();
                        _phoneController.clear();
                        _websiteController.clear();
                        _instagramController.clear();
                      },
                      icon: const Icon(Icons.close),
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Text(
                'If this vendor has a HiPop account, search for them by email to auto-populate contact information.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Search by email',
                        hintText: 'vendor@example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) => _userSearchEmail = value,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _searchUserByEmail,
                    child: const Text('Search'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContactLocationPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Contact & Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildUserProfileLinkSection(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'EMAIL',
              border: const OutlineInputBorder(),
              suffixIcon: _linkedUserProfile != null 
                  ? const Icon(Icons.link, color: Colors.green)
                  : null,
              helperText: _linkedUserProfile != null 
                  ? 'From linked profile'
                  : null,
            ),
            keyboardType: TextInputType.emailAddress,
            readOnly: _linkedUserProfile != null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: InputDecoration(
              labelText: 'PHONE NUMBER',
              border: const OutlineInputBorder(),
              suffixIcon: _linkedUserProfile != null 
                  ? const Icon(Icons.link, color: Colors.green)
                  : null,
              helperText: _linkedUserProfile != null 
                  ? 'From linked profile'
                  : null,
            ),
            keyboardType: TextInputType.phone,
            readOnly: _linkedUserProfile != null,
          ),
          const SizedBox(height: 16),
          _buildStringListField(
            'CONTACTS',
            'If there are others that need to be cc\'d on your email communications regarding the event, please let us know their email',
            _ccEmails,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _websiteController,
            decoration: InputDecoration(
              labelText: 'Website',
              border: const OutlineInputBorder(),
              hintText: 'https://...',
              suffixIcon: _linkedUserProfile != null 
                  ? const Icon(Icons.link, color: Colors.green)
                  : null,
              helperText: _linkedUserProfile != null 
                  ? 'From linked profile'
                  : null,
            ),
            keyboardType: TextInputType.url,
            readOnly: _linkedUserProfile != null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _instagramController,
                  decoration: InputDecoration(
                    labelText: 'Instagram Handle',
                    border: const OutlineInputBorder(),
                    hintText: 'username (without @)',
                    suffixIcon: _linkedUserProfile != null 
                        ? const Icon(Icons.link, color: Colors.green)
                        : null,
                    helperText: _linkedUserProfile != null 
                        ? 'From linked profile'
                        : null,
                  ),
                  readOnly: _linkedUserProfile != null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook Page',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _zipController,
                  decoration: const InputDecoration(
                    labelText: 'Zip Code',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsServicesPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Products & Services',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildStringListField(
            'Products',
            'What does this vendor sell?',
            _products,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _specificProductsController,
            decoration: const InputDecoration(
              labelText: 'PRODUCT SOLD, BE SPECIFIC',
              border: OutlineInputBorder(),
              hintText: 'This helps us ensure we don\'t have too much of the same product',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          _buildStringListField(
            'Specialties',
            'What are they known for?',
            _specialties,
          ),
          const SizedBox(height: 16),
          _buildStringListField(
            'Tags',
            'Keywords for search',
            _tags,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _priceRangeController,
            decoration: const InputDecoration(
              labelText: 'Price Range',
              border: OutlineInputBorder(),
              hintText: '\$, \$\$, or \$\$\$',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _certificationsController,
            decoration: const InputDecoration(
              labelText: 'Certifications',
              border: OutlineInputBorder(),
              hintText: 'Organic, Fair Trade, etc.',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Organic',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: _isOrganic,
                          onChanged: (value) {
                            setState(() {
                              _isOrganic = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Locally\nSourced',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: _isLocallySourced,
                          onChanged: (value) {
                            setState(() {
                              _isLocallySourced = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Can Deliver',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: _canDeliver,
                          onChanged: (value) {
                            setState(() {
                              _canDeliver = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Text(
                          'Accepts\nOrders',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Switch(
                          value: _acceptsOrders,
                          onChanged: (value) {
                            setState(() {
                              _acceptsOrders = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_canDeliver) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _deliveryNotesController,
              decoration: const InputDecoration(
                labelText: 'Delivery Notes',
                border: OutlineInputBorder(),
                hintText: 'Delivery area, fees, etc.',
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdditionalInfoPage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _storyController,
            decoration: const InputDecoration(
              labelText: 'Vendor Story',
              border: OutlineInputBorder(),
              hintText: 'Background, history, mission...',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          const Text(
            'Operating Days',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              'Monday', 'Tuesday', 'Wednesday', 'Thursday', 
              'Friday', 'Saturday', 'Sunday'
            ].map((day) {
              final isSelected = _operatingDays.contains(day);
              return FilterChip(
                label: Text(day),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _operatingDays.add(day);
                    } else {
                      _operatingDays.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _boothPreferencesController,
            decoration: const InputDecoration(
              labelText: 'Booth Preferences',
              border: OutlineInputBorder(),
              hintText: 'Size, location preferences...',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _specialRequirementsController,
            decoration: const InputDecoration(
              labelText: 'Special Requirements',
              border: OutlineInputBorder(),
              hintText: 'Electricity, water, etc.',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildStringListField(String label, String hint, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            TextButton.icon(
              onPressed: () => _addStringItem(items),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hint,
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) => Chip(
              label: Text(item),
              onDeleted: () {
                setState(() {
                  items.remove(item);
                });
              },
            )).toList(),
          ),
      ],
    );
  }

  void _addStringItem(List<String> items) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Add Item'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter item name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty && !items.contains(text)) {
                  setState(() {
                    items.add(text);
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

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentPage > 0)
          Flexible(
            child: TextButton.icon(
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
            ),
          ),
        const Spacer(),
        if (_currentPage < 3)
          Flexible(
            child: ElevatedButton.icon(
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          )
        else
          Flexible(
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _saveVendor,
              icon: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isEditing ? Icons.save : Icons.add),
              label: Text(isEditing ? 'Update' : 'Create'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _saveVendor() async {
    if (!_formKey.currentState!.validate()) {
      // Go to first page with validation errors
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: Colors.orange,
        ),
      );
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final vendor = ManagedVendor(
        id: isEditing ? widget.vendor!.id : '',
        marketId: widget.marketId,
        organizerId: widget.organizerId,
        userProfileId: _linkedUserProfile?.userId,
        businessName: _businessNameController.text.trim(),
        vendorName: _vendorNameController.text.trim().isEmpty ? null : _vendorNameController.text.trim(),
        contactName: _contactNameController.text.trim(),
        description: _descriptionController.text.trim(),
        categories: _selectedCategories,
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        ccEmails: _ccEmails,
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        instagramHandle: _instagramController.text.trim().isEmpty ? null : _instagramController.text.trim(),
        facebookHandle: _facebookController.text.trim().isEmpty ? null : _facebookController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
        state: _stateController.text.trim().isEmpty ? null : _stateController.text.trim(),
        zipCode: _zipController.text.trim().isEmpty ? null : _zipController.text.trim(),
        canDeliver: _canDeliver,
        acceptsOrders: _acceptsOrders,
        deliveryNotes: _deliveryNotesController.text.trim().isEmpty ? null : _deliveryNotesController.text.trim(),
        products: _products,
        specificProducts: _specificProductsController.text.trim().isEmpty ? null : _specificProductsController.text.trim(),
        specialties: _specialties,
        priceRange: _priceRangeController.text.trim().isEmpty ? null : _priceRangeController.text.trim(),
        isOrganic: _isOrganic,
        isLocallySourced: _isLocallySourced,
        certifications: _certificationsController.text.trim().isEmpty ? null : _certificationsController.text.trim(),
        isActive: _isActive,
        isFeatured: _isFeatured,
        operatingDays: _operatingDays,
        boothPreferences: _boothPreferencesController.text.trim().isEmpty ? null : _boothPreferencesController.text.trim(),
        specialRequirements: _specialRequirementsController.text.trim().isEmpty ? null : _specialRequirementsController.text.trim(),
        story: _storyController.text.trim().isEmpty ? null : _storyController.text.trim(),
        tags: _tags,
        slogan: _sloganController.text.trim().isEmpty ? null : _sloganController.text.trim(),
        createdAt: isEditing ? widget.vendor!.createdAt : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEditing) {
        await ManagedVendorService.updateVendor(vendor.id, vendor);
      } else {
        await ManagedVendorService.createVendor(vendor);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing 
                  ? '${vendor.businessName} updated successfully!' 
                  : '${vendor.businessName} created successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${isEditing ? 'updating' : 'creating'} vendor: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}