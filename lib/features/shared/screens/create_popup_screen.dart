import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/vendor/services/vendor_market_relationship_service.dart';
import '../../../repositories/vendor_posts_repository.dart';
import '../../market/models/market.dart';
import '../widgets/common/hipop_text_field.dart';
import '../widgets/common/simple_places_widget.dart';
import '../widgets/common/photo_upload_widget.dart';
import '../services/places_service.dart';
import '../services/photo_service.dart';
import '../../market/services/market_service.dart';
import '../services/user_profile_service.dart';
import '../models/user_profile.dart';
import 'dart:io';

class CreatePopUpScreen extends StatefulWidget {
  final IVendorPostsRepository postsRepository;
  final VendorPost? editingPost;

  const CreatePopUpScreen({
    super.key,
    required this.postsRepository,
    this.editingPost,
  });

  @override
  State<CreatePopUpScreen> createState() => _CreatePopUpScreenState();
}

class _CreatePopUpScreenState extends State<CreatePopUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  final UserProfileService _userProfileService = UserProfileService();
  UserProfile? _currentUserProfile;
  
  List<File> _selectedPhotos = [];
  
  DateTime? _selectedStartDateTime;
  DateTime? _selectedEndDateTime;
  bool _isLoading = false;
  PlaceDetails? _selectedPlace;
  
  List<Market> _availableMarkets = [];
  List<Market> _approvedMarkets = [];
  Market? _selectedMarket;
  bool _loadingMarkets = false;
  bool _loadingApprovedMarkets = false;
  String? _popupType;
  bool _isIndependent = false;
  bool _canAccessMarkets = false;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
    _loadCurrentUserProfile();
    // Defer form initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeForm();
    });
  }

  Future<void> _loadCurrentUserProfile() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      try {
        _currentUserProfile = await _userProfileService.getUserProfile(currentUser.uid);
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint('Error loading user profile: $e');
      }
    }
  }

  void _initializeForm() {
    // Check for type parameter from query string
    final uri = GoRouterState.of(context).uri;
    _popupType = uri.queryParameters['type'];
    
    // Check for duplicate arguments first
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final duplicateFrom = args?['duplicateFrom'] as VendorPost?;
    
    if (duplicateFrom != null) {
      // Duplicate mode - copy all details except date/time
      _vendorNameController.text = duplicateFrom.vendorName;
      _locationController.text = duplicateFrom.location;
      _descriptionController.text = duplicateFrom.description;
      // Instagram handle will be auto-populated from user profile
      // Don't copy date/time for duplicates - let user set new ones
      
      // Initialize selected place if we have location data
      if (duplicateFrom.placeId != null && duplicateFrom.latitude != null && duplicateFrom.longitude != null) {
        _selectedPlace = PlaceDetails(
          placeId: duplicateFrom.placeId!,
          name: duplicateFrom.locationName ?? duplicateFrom.location,
          formattedAddress: duplicateFrom.location,
          latitude: duplicateFrom.latitude!,
          longitude: duplicateFrom.longitude!,
        );
      }
      
      // Set selected market if available
      if (duplicateFrom.marketId != null) {
        _setSelectedMarketById(duplicateFrom.marketId!);
      }
      
      // For duplication, we'll start with empty photos and let user add new ones
    } else if (widget.editingPost != null) {
      // Edit mode - copy everything including date/time
      final post = widget.editingPost!;
      _vendorNameController.text = post.vendorName;
      _locationController.text = post.location;
      _descriptionController.text = post.description;
      // Instagram handle will be auto-populated from user profile
      _selectedStartDateTime = post.popUpStartDateTime;
      _selectedEndDateTime = post.popUpEndDateTime;
      
      // Initialize selected place if we have location data
      if (post.placeId != null && post.latitude != null && post.longitude != null) {
        _selectedPlace = PlaceDetails(
          placeId: post.placeId!,
          name: post.locationName ?? post.location,
          formattedAddress: post.location,
          latitude: post.latitude!,
          longitude: post.longitude!,
        );
      }
      
      // Set selected market if available
      if (post.marketId != null) {
        _setSelectedMarketById(post.marketId!);
      }
      
      // For editing, the PhotoUploadWidget will handle existing photos via initialImagePaths
    } else {
      // New post mode - set default vendor name from user profile
      final user = FirebaseAuth.instance.currentUser;
      _vendorNameController.text = user?.displayName ?? '';
      
      // Set type based on URL parameter
      if (_popupType == 'independent') {
        setState(() {
          _isIndependent = true;
          _selectedMarket = null;
        });
      } else if (_popupType == 'market') {
        setState(() {
          _isIndependent = false;
        });
      } else {
        // Default to independent unless user has approved markets
        setState(() {
          _isIndependent = !_canAccessMarkets;
        });
      }
    }
  }
  
  Future<void> _loadMarkets() async {
    setState(() => _loadingMarkets = true);
    
    try {
      // Load all active markets in the Atlanta metro area
      final markets = await MarketService.getAllActiveMarkets();
      setState(() {
        _availableMarkets = markets;
        _loadingMarkets = false;
      });
      
      // Load approved markets after all markets are loaded
      _loadApprovedMarkets();
    } catch (e) {
      setState(() => _loadingMarkets = false);
    }
  }
  
  Future<void> _loadApprovedMarkets() async {
    setState(() => _loadingApprovedMarkets = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Get markets the vendor has permission for
        final approvedMarketIds = await VendorMarketRelationshipService.getApprovedMarketsForVendor(user.uid);
        
        // Filter the available markets to only show approved ones
        final approvedMarkets = _availableMarkets.where((market) => 
          approvedMarketIds.contains(market.id)
        ).toList();
        
        setState(() {
          _approvedMarkets = approvedMarkets;
          _canAccessMarkets = approvedMarkets.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint('Error loading approved markets: $e');
    } finally {
      setState(() => _loadingApprovedMarkets = false);
    }
  }
  
  void _setSelectedMarketById(String marketId) {
    final market = _availableMarkets.firstWhere(
      (m) => m.id == marketId,
      orElse: () => Market(
        id: marketId,
        name: 'Unknown Market',
        address: '',
        city: '',
        state: '',
        latitude: 0,
        longitude: 0,
        operatingDays: {},
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );
    setState(() => _selectedMarket = market);
  }

  @override
  void dispose() {
    _vendorNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingPost != null ? 'Edit Pop-Up' : 'Create Pop-Up'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 32),
            _buildFormFields(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    IconData iconData;
    String title;
    String subtitle;
    
    if (widget.editingPost != null) {
      iconData = Icons.edit;
      title = 'Update Your Pop-Up';
      subtitle = 'Make changes to your existing event';
    } else {
      iconData = Icons.store;
      title = 'Create Your Pop-Up';
      subtitle = 'Set up your vendor event anywhere you want';
    }

    return Column(
      children: [
        Icon(
          iconData,
          size: 64,
          color: Theme.of(context).primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        if (_popupType != 'independent') ...[
          const SizedBox(height: 8),
          Text(
            'You can optionally associate with a market or go completely independent!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HiPopTextField(
          controller: _vendorNameController,
          labelText: 'Your Business Name',
          prefixIcon: const Icon(Icons.business),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your business name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            SimplePlacesWidget(
              initialLocation: _locationController.text,
              onLocationSelected: (location) {
                setState(() {
                  _locationController.text = location?.formattedAddress ?? '';
                  // Store the selected place for location data
                  _selectedPlace = location;
                });
              },
            ),
            if (_locationController.text.isEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Please enter or select a location',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (_popupType != 'independent') ...[
          _buildMarketPicker(),
          const SizedBox(height: 16),
        ],
        _buildDateTimePicker(),
        const SizedBox(height: 16),
        HiPopTextField(
          controller: _descriptionController,
          labelText: 'Description',
          hintText: 'Tell customers what you\'ll be selling...',
          prefixIcon: const Icon(Icons.description),
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            if (value.trim().length < 10) {
              return 'Description must be at least 10 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        PhotoUploadWidget(
          onPhotosSelected: (photos) {
            setState(() {
              _selectedPhotos = photos;
            });
          },
          initialImagePaths: widget.editingPost?.photoUrls,
          userId: FirebaseAuth.instance.currentUser?.uid,
          userType: 'vendor',
        ),
        const SizedBox(height: 16),
        _buildInstagramInfoWidget(),
      ],
    );
  }

  Widget _buildInstagramInfoWidget() {
    final instagramHandle = _currentUserProfile?.instagramHandle;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Row(
        children: [
          const Icon(Icons.camera_alt, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instagram Handle',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  instagramHandle?.isNotEmpty == true 
                      ? '@$instagramHandle'
                      : 'Not set in profile',
                  style: TextStyle(
                    fontSize: 16,
                    color: instagramHandle?.isNotEmpty == true 
                        ? Colors.black87 
                        : Colors.grey,
                  ),
                ),
                if (instagramHandle?.isEmpty != false)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Update your Instagram handle in your profile settings',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker() {
    return Column(
      children: [
        // Start Time Picker
        InkWell(
          onTap: () => _selectStartDateTime(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.play_arrow, color: Colors.green[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Time',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedStartDateTime != null
                            ? _formatDateTime(_selectedStartDateTime!)
                            : 'Select when your pop-up starts',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedStartDateTime != null 
                              ? Colors.black87 
                              : Colors.grey[500],
                          fontWeight: _selectedStartDateTime != null 
                              ? FontWeight.w500 
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // End Time Picker
        InkWell(
          onTap: () => _selectEndDateTime(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Icon(Icons.stop, color: Colors.red[600]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Time',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedEndDateTime != null
                            ? _formatDateTime(_selectedEndDateTime!)
                            : 'Select when your pop-up ends',
                        style: TextStyle(
                          fontSize: 16,
                          color: _selectedEndDateTime != null 
                              ? Colors.black87 
                              : Colors.grey[500],
                          fontWeight: _selectedEndDateTime != null 
                              ? FontWeight.w500 
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        HiPopButton(
          text: widget.editingPost != null ? 'Update Pop-Up' : 'Create Pop-Up',
          onPressed: _isLoading ? null : _savePost,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _isLoading ? null : () => context.pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _selectStartDateTime() async {
    final now = DateTime.now();
    final initialDate = _selectedStartDateTime ?? now.add(const Duration(hours: 1));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).primaryColor,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final selectedStart = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        
        setState(() {
          _selectedStartDateTime = selectedStart;
          // Auto-set end time to 4 hours later if not already set
          if (_selectedEndDateTime == null || _selectedEndDateTime!.isBefore(selectedStart)) {
            _selectedEndDateTime = selectedStart.add(const Duration(hours: 4));
          }
        });
      }
    }
  }

  Future<void> _selectEndDateTime() async {
    if (_selectedStartDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start time first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final minDate = _selectedStartDateTime!;
    final initialDate = _selectedEndDateTime ?? minDate.add(const Duration(hours: 4));
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: minDate.add(const Duration(days: 7)), // Max 1 week duration
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).primaryColor,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final selectedEnd = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        
        if (selectedEnd.isAfter(_selectedStartDateTime!)) {
          setState(() {
            _selectedEndDateTime = selectedEnd;
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (selectedDate == today) {
      dateStr = 'Today';
    } else if (selectedDate == today.add(const Duration(days: 1))) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${_getMonthName(dateTime.month)} ${dateTime.day}, ${dateTime.year}';
    }
    
    final hour = dateTime.hour == 0 ? 12 : dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$dateStr at $hour:$minute $period';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
  
  Widget _buildMarketPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Market Association (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: _loadingMarkets
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Loading markets...'),
                    ],
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<Market?>(
                    value: _selectedMarket,
                    isExpanded: true,
                    hint: const Text('Independent pop-up (no market)'),
                    items: [
                      const DropdownMenuItem<Market?>(
                        value: null,
                        child: Text('Independent - no market association'),
                      ),
                      ..._availableMarkets.map((market) {
                        return DropdownMenuItem<Market?>(
                          value: market,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  market.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• ${market.address.split(',').first}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (Market? market) {
                      setState(() {
                        _selectedMarket = market;
                        // Don't auto-fill location when market is selected
                        // Let vendors choose their own location
                      });
                    },
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, 
                   size: 16, 
                   color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedMarket != null
                      ? 'Your pop-up will be associated with ${_selectedMarket!.name} but you can still choose any location.'
                      : 'You\'re creating an independent pop-up at your chosen location.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or select a location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedStartDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start time for your pop-up'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedEndDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an end time for your pop-up'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedStartDateTime!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pop-up start time must be in the future'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedEndDateTime!.isBefore(_selectedStartDateTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pop-up end time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final now = DateTime.now();
      
      if (widget.editingPost != null) {
        // Update existing post
        List<String> photoUrls = widget.editingPost!.photoUrls;
        
        // Upload new photos if any
        if (_selectedPhotos.isNotEmpty) {
          // Filter out existing photos (File objects created from URLs won't be real files)
          final newPhotos = _selectedPhotos.where((photo) => photo.existsSync()).toList();
          if (newPhotos.isNotEmpty) {
            final newUrls = await PhotoService.uploadPostPhotos(widget.editingPost!.id, newPhotos);
            photoUrls = [...photoUrls, ...newUrls];
          }
        }
        
        final updatedPost = widget.editingPost!.copyWith(
          vendorName: _vendorNameController.text.trim(),
          location: _locationController.text.trim(),
          latitude: _selectedPlace?.latitude,
          longitude: _selectedPlace?.longitude,
          placeId: _selectedPlace?.placeId,
          locationName: _selectedPlace?.name,
          locationKeywords: _selectedPlace != null 
              ? VendorPost.generateLocationKeywords(_selectedPlace!.formattedAddress)
              : VendorPost.generateLocationKeywords(_locationController.text.trim()),
          popUpStartDateTime: _selectedStartDateTime!,
          popUpEndDateTime: _selectedEndDateTime!,
          description: _descriptionController.text.trim(),
          instagramHandle: _currentUserProfile?.instagramHandle,
          photoUrls: photoUrls,
          marketId: _selectedMarket?.id,
          updatedAt: now,
        );
        
        await widget.postsRepository.updatePost(updatedPost);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pop-up updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      } else {
        // Create new post
        final tempPost = VendorPost(
          id: '', // Will be set by repository
          vendorId: user.uid,
          vendorName: _vendorNameController.text.trim(),
          location: _locationController.text.trim(),
          latitude: _selectedPlace?.latitude,
          longitude: _selectedPlace?.longitude,
          placeId: _selectedPlace?.placeId,
          locationName: _selectedPlace?.name,
          locationKeywords: _selectedPlace != null 
              ? VendorPost.generateLocationKeywords(_selectedPlace!.formattedAddress)
              : VendorPost.generateLocationKeywords(_locationController.text.trim()),
          popUpStartDateTime: _selectedStartDateTime!,
          popUpEndDateTime: _selectedEndDateTime!,
          description: _descriptionController.text.trim(),
          instagramHandle: _currentUserProfile?.instagramHandle,
          marketId: _selectedMarket?.id,
          createdAt: now,
          updatedAt: now,
        );
        
        // Create the post first to get an ID
        final postId = await widget.postsRepository.createPost(tempPost);
        
        // Upload photos if any
        List<String> photoUrls = [];
        if (_selectedPhotos.isNotEmpty) {
          photoUrls = await PhotoService.uploadPostPhotos(postId, _selectedPhotos);
          
          // Update the post with photo URLs
          if (photoUrls.isNotEmpty) {
            final finalPost = tempPost.copyWith(
              id: postId,
              photoUrls: photoUrls,
            );
            await widget.postsRepository.updatePost(finalPost);
          }
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pop-up created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving pop-up: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}