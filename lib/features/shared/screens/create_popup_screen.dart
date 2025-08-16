import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/features/vendor/models/vendor_post.dart';
import 'package:hipop/features/vendor/models/post_type.dart';
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
import '../../vendor/services/vendor_product_service.dart';
import '../../vendor/models/vendor_product_list.dart';
import '../../premium/services/subscription_service.dart';
import '../services/real_time_analytics_service.dart';
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
  final _vendorNotesController = TextEditingController();
  
  final UserProfileService _userProfileService = UserProfileService();
  UserProfile? _currentUserProfile;
  
  List<File> _selectedPhotos = [];
  
  DateTime? _selectedStartDateTime;
  DateTime? _selectedEndDateTime;
  bool _isLoading = false;
  PlaceDetails? _selectedPlace;
  
  List<Market> _availableMarkets = [];
  Market? _selectedMarket;
  bool _loadingMarkets = false;
  String? _popupType;
  bool _isIndependent = false;
  
  // Product list integration
  List<VendorProductList> _availableProductLists = [];
  List<VendorProductList> _selectedProductLists = [];
  bool _loadingProductLists = false;
  
  // Premium subscription tracking
  bool _canCreatePost = true;
  bool _isCheckingLimits = false;
  int _remainingPosts = -1; // -1 means unlimited
  bool _isNearLimit = false; // true when 1 away from limit
  Map<String, dynamic>? _subscriptionInfo;

  @override
  void initState() {
    super.initState();
    _loadMarkets();
    _loadCurrentUserProfile();
    _loadProductLists();
    _checkSubscriptionLimits();
    
    // Track post creation start
    _trackPostCreationStart();
    
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

  Future<void> _loadProductLists() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _loadingProductLists = true;
    });

    try {
      final productLists = await VendorProductService.getProductLists(currentUser.uid);
      if (mounted) {
        setState(() {
          _availableProductLists = productLists;
          _loadingProductLists = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading product lists: $e');
      if (mounted) {
        setState(() {
          _loadingProductLists = false;
        });
      }
    }
  }

  Future<void> _checkSubscriptionLimits() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isCheckingLimits = true;
    });

    try {
      final subscription = await SubscriptionService.getUserSubscription(currentUser.uid);
      final userProfile = await _userProfileService.getUserProfile(currentUser.uid);
      final userType = subscription?.userType ?? userProfile?.userType ?? 'vendor';
      
      if (userType == 'vendor') {
        // For vendors, check popup creation limits
        if (subscription?.isPremium == true) {
          _remainingPosts = -1; // Unlimited for premium
          _canCreatePost = true;
          _isNearLimit = false;
        } else {
          // Free tier vendor - check popup_posts_per_month limit
          final limit = subscription?.getLimit('popup_posts_per_month') ?? 3;
          // Get current usage from vendor_stats collection
          final currentUsage = await _getCurrentMonthlyPostCount(currentUser.uid);
          _remainingPosts = limit - currentUsage;
          _canCreatePost = _remainingPosts > 0;
          _isNearLimit = _remainingPosts == 1;
        }
      } else if (userType == 'market_organizer') {
        // Check organizer limits using same system as vendors
        if (subscription?.isPremium == true) {
          _remainingPosts = -1; // Unlimited for premium
          _canCreatePost = true;
          _isNearLimit = false;
        } else {
          // Free tier organizer - check same monthly limit as vendors
          const limit = 3; // Same limit as vendors
          final currentUsage = await _getCurrentMonthlyPostCount(currentUser.uid);
          _remainingPosts = limit - currentUsage;
          _canCreatePost = _remainingPosts > 0;
          _isNearLimit = _remainingPosts == 1;
        }
      } else {
        _canCreatePost = true; // Default to allowing for other user types
        _remainingPosts = -1;
        _isNearLimit = false;
      }

      if (mounted) {
        setState(() {
          _subscriptionInfo = {
            'subscription': subscription,
            'userType': subscription?.userType ?? _currentUserProfile?.userType ?? 'vendor',
            'isPremium': subscription?.isPremium ?? false,
            'canCreate': _canCreatePost,
          };
          _isCheckingLimits = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking subscription limits: $e');
      if (mounted) {
        setState(() {
          _canCreatePost = true; // Default to allowing on error
          _isCheckingLimits = false;
        });
      }
    }
  }

  void _initializeForm() {
    // Check for type parameter from query string
    final uri = GoRouterState.of(context).uri;
    _popupType = uri.queryParameters['type'];
    final marketId = uri.queryParameters['marketId'];
    
    // Track post type selection
    _trackPostTypeSelection(_popupType);
    
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
      _vendorNotesController.text = post.vendorNotes ?? '';
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
        // Default to independent
        setState(() {
          _isIndependent = true;
        });
      }
      
      // Set selected market if marketId is provided
      if (marketId != null && marketId.isNotEmpty) {
        _setSelectedMarketById(marketId);
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
      
    } catch (e) {
      setState(() => _loadingMarkets = false);
    }
  }
  
  
  Future<void> _setSelectedMarketById(String marketId) async {
    // Try to find in already loaded markets first
    Market? market = _availableMarkets.firstWhere(
      (m) => m.id == marketId,
      orElse: () => Market(
        id: marketId,
        name: 'Loading...',
        address: '',
        city: '',
        state: '',
        latitude: 0,
        longitude: 0,
        eventDate: DateTime.now(),
        startTime: '9:00 AM',
        endTime: '5:00 PM',
        isActive: true,
        createdAt: DateTime.now(),
      ),
    );
    
    // If not found in available markets, fetch it directly
    if (market.name == 'Loading...') {
      try {
        final fetchedMarket = await MarketService.getMarket(marketId);
        if (fetchedMarket != null) {
          market = fetchedMarket;
          // Add to available markets if not already there
          if (!_availableMarkets.any((m) => m.id == marketId)) {
            _availableMarkets.add(fetchedMarket);
          }
        }
      } catch (e) {
        debugPrint('Error fetching market: $e');
      }
    }
    
    if (mounted) {
      final previousMarketId = _selectedMarket?.id;
      setState(() {
        _selectedMarket = market;
        // Pre-fill location and time from market data
        if (market != null && market.name != 'Loading...') {
          _locationController.text = '${market.address}, ${market.city}, ${market.state}';
          _selectedPlace = PlaceDetails(
            placeId: market.id,
            name: market.name,
            formattedAddress: '${market.address}, ${market.city}, ${market.state}',
            latitude: market.latitude,
            longitude: market.longitude,
          );
          // Pre-fill time if market has operating hours for today
          _prefillMarketTime(market);
        }
      });
      
      // Track market selection change
      if (previousMarketId != market?.id) {
        _trackMarketSelection(market?.id);
      }
    }
  }
  
  void _prefillMarketTime(Market market) {
    // Get today's day name
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    
    // Check if market is happening today
    if (market.isHappeningToday) {
      String hours = '${market.startTime} - ${market.endTime}';
      // Parse hours like "9:00 AM-2:00 PM"
      try {
        // Extract just the time portion if it includes date info
        if (hours.contains('(')) {
          hours = hours.substring(0, hours.indexOf('(')).trim();
        }
        
        final parts = hours.split('-');
        if (parts.length == 2) {
          final startTime = _parseTimeString(parts[0].trim());
          final endTime = _parseTimeString(parts[1].trim());
          
          if (startTime != null && endTime != null) {
            setState(() {
              _selectedStartDateTime = DateTime(
                now.year, now.month, now.day,
                startTime.hour, startTime.minute,
              );
              _selectedEndDateTime = DateTime(
                now.year, now.month, now.day,
                endTime.hour, endTime.minute,
              );
            });
          }
        }
      } catch (e) {
        debugPrint('Error parsing market hours: $e');
      }
    }
  }
  
  DateTime? _parseTimeString(String timeStr) {
    try {
      // Parse time like "9:00 AM" or "2:00 PM"
      final isPM = timeStr.toUpperCase().contains('PM');
      final isAM = timeStr.toUpperCase().contains('AM');
      
      // Remove AM/PM and trim
      String cleanTime = timeStr.replaceAll(RegExp(r'[AP]M', caseSensitive: false), '').trim();
      
      final timeParts = cleanTime.split(':');
      if (timeParts.length != 2) return null;
      
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      // Convert to 24-hour format
      if (isPM && hour != 12) {
        hour += 12;
      } else if (isAM && hour == 12) {
        hour = 0;
      }
      
      return DateTime(2000, 1, 1, hour, minute);
    } catch (e) {
      debugPrint('Error parsing time string: $e');
      return null;
    }
  }
  
  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return '';
    }
  }
  
  Map<String, DateTime>? _getNextMarketDay(Market market) {
    // Find the next available market day
    final now = DateTime.now();
    
    // Check next 30 days for market hours
    for (int i = 0; i < 30; i++) {
      final checkDate = now.add(Duration(days: i));
      final dayName = _getDayName(checkDate.weekday);
      
      // Check if market event date matches the check date
      if (market.eventDate.year == checkDate.year && 
          market.eventDate.month == checkDate.month && 
          market.eventDate.day == checkDate.day) {
        String hours = '${market.startTime} - ${market.endTime}';
        // Parse hours
        if (hours.contains('(')) {
          hours = hours.substring(0, hours.indexOf('(')).trim();
        }
        
        final parts = hours.split('-');
        if (parts.length == 2) {
          final startTime = _parseTimeString(parts[0].trim());
          final endTime = _parseTimeString(parts[1].trim());
          
          if (startTime != null && endTime != null) {
            final start = DateTime(
              checkDate.year, checkDate.month, checkDate.day,
              startTime.hour, startTime.minute,
            );
            final end = DateTime(
              checkDate.year, checkDate.month, checkDate.day,
              endTime.hour, endTime.minute,
            );
            
            // Only return if the time is in the future
            if (start.isAfter(now)) {
              return {'start': start, 'end': end};
            }
          }
        }
      }
    }
    
    return null;
  }

  @override
  void dispose() {
    // Track abandonment if user exits without completing
    if (!_isLoading) {
      _trackPostCreationAbandonment();
    }
    
    _vendorNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _vendorNotesController.dispose();
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
            const SizedBox(height: 16),
            if (!_canCreatePost) _buildUpgradeBanner(),
            if (!_canCreatePost) const SizedBox(height: 16),
            if (_isNearLimit && _canCreatePost) _buildWarningBanner(),
            if (_isNearLimit && _canCreatePost) const SizedBox(height: 16),
            const SizedBox(height: 16),
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
    } else if (_popupType == 'market' && _selectedMarket != null) {
      iconData = Icons.storefront;
      title = 'Create Market Pop-Up';
      subtitle = 'Submit your pop-up for market approval';
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
        // Show monthly limit for ALL post types (free users limited to 3 total per month)
        if (_remainingPosts > 0 && _remainingPosts != -1) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _remainingPosts == 1 ? Colors.orange.shade100 : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _remainingPosts == 1 ? Colors.orange.shade300 : Colors.blue.shade200,
              ),
            ),
            child: Text(
              _remainingPosts == 1 
                ? '⚠️ Last post this month' 
                : '📊 $_remainingPosts posts remaining this month',
              style: TextStyle(
                color: _remainingPosts == 1 ? Colors.orange.shade700 : Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
        // Show selected market prominently if one is selected
        if (_selectedMarket != null && _popupType == 'market') ...[
          _buildSelectedMarketCard(),
          const SizedBox(height: 20),
        ],
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
        // Only show location picker for independent posts
        if (_popupType != 'market' || _selectedMarket == null) ...[
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
                  _trackFormFieldInteraction('location', location?.formattedAddress);
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
        ],
        // Only show date/time picker for independent posts
        if (_popupType != 'market' || _selectedMarket == null) ...[
          _buildDateTimePicker(),
          const SizedBox(height: 16),
        ],
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
        
        // Add vendor notes field for market posts
        if (_popupType == 'market' || (_selectedMarket != null && !_isIndependent)) ...[
          HiPopTextField(
            controller: _vendorNotesController,
            labelText: 'Message to Market Organizer (Optional)',
            hintText: 'Add any special requests or information for the organizer...',
            prefixIcon: const Icon(Icons.message),
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            validator: null, // Optional field
          ),
          const SizedBox(height: 16),
        ],
        
        PhotoUploadWidget(
          onPhotosSelected: (photos) {
            setState(() {
              _selectedPhotos = photos;
            });
            _trackPhotoUploadInteraction(photos);
          },
          initialImagePaths: widget.editingPost?.photoUrls,
          userId: FirebaseAuth.instance.currentUser?.uid,
          userType: _subscriptionInfo?['userType'] ?? 'vendor',
        ),
        const SizedBox(height: 16),
        _buildProductListSelectionWidget(),
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
  
  String _getMarketScheduleText() {
    if (_selectedMarket == null) return 'Market schedule';
    
    // Debug: Log market event details
    debugPrint('Market ${_selectedMarket!.name} event: ${_selectedMarket!.eventDisplayInfo}');
    
    // If we have pre-filled start/end times from the market, use those
    if (_selectedStartDateTime != null && _selectedEndDateTime != null) {
      final dateStr = _formatDate(_selectedStartDateTime!);
      final startTime = _formatTime(_selectedStartDateTime!);
      final endTime = _formatTime(_selectedEndDateTime!);
      return '$dateStr: $startTime-$endTime';
    }
    
    // Get the next market day
    final nextDay = _getNextMarketDay(_selectedMarket!);
    if (nextDay != null) {
      final start = nextDay['start']!;
      final end = nextDay['end']!;
      final dateStr = _formatDate(start);
      final startTime = _formatTime(start);
      final endTime = _formatTime(end);
      return '$dateStr: $startTime-$endTime';
    }
    
    // Fallback: Check today's hours
    final now = DateTime.now();
    final dayName = _getDayName(now.weekday);
    // Check if market is happening today
    if (_selectedMarket!.isHappeningToday) {
      String hours = '${_selectedMarket!.startTime} - ${_selectedMarket!.endTime}';
      // Extract just the time portion if it includes date info
      if (hours.contains('(')) {
        hours = hours.substring(0, hours.indexOf('(')).trim();
      }
      return 'Today: $hours';
    }
    
    return 'Market schedule varies';
  }
  
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
  
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }
  
  Widget _buildSelectedMarketCard() {
    if (_selectedMarket == null) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.storefront,
                  color: Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Market-Associated Pop-Up',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedMarket!.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_selectedMarket!.address}, ${_selectedMarket!.city}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _getMarketScheduleText(),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This post will be submitted for market organizer approval',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
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

  Widget _buildProductListSelectionWidget() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.blue[600]),
                const SizedBox(width: 12),
                const Text(
                  'Product Lists (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (_loadingProductLists)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          if (_availableProductLists.isEmpty && !_loadingProductLists)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'No product lists found. Create product lists to showcase your items.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            )
          else if (_availableProductLists.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Select product lists to showcase at this pop-up:',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _availableProductLists.length,
                itemBuilder: (context, index) {
                  final productList = _availableProductLists[index];
                  final isSelected = _selectedProductLists.contains(productList);
                  
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedProductLists.remove(productList);
                          } else {
                            _selectedProductLists.add(productList);
                          }
                        });
                        _trackFormFieldInteraction('product_lists', _selectedProductLists.length);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected ? Colors.blue.shade50 : Colors.white,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    productList.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isSelected ? Colors.blue[800] : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.blue[600],
                                    size: 16,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${productList.productIds.length} items',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (productList.description?.isNotEmpty == true)
                              Expanded(
                                child: Text(
                                  productList.description!,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              Expanded(
                                child: Text(
                                  'Product list',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
        _trackDateTimeSelection(selectedStart, 'start');
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
          _trackDateTimeSelection(selectedEnd, 'end');
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
  
  Widget _buildUpgradeBanner() {
    final userType = _subscriptionInfo?['userType'] ?? 'vendor';
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.purple.shade600,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.yellow.shade300,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getUpgradeTitle(userType),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _getUpgradeDescription(userType),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: _getUpgradeBenefits(userType).map((benefit) => 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.yellow.shade300,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _navigateToUpgrade(userType),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purple.shade700,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Upgrade to ${_getPremiumTierName(userType)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _showUpgradeDetails(userType),
                child: Text(
                  'Learn More',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    final userType = _subscriptionInfo?['userType'] ?? 'vendor';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade400,
            Colors.amber.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _remainingPosts == 1 
                    ? 'Only 1 popup left this month!'
                    : 'Almost at your limit!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userType == 'vendor' 
                    ? 'You have $_remainingPosts popup${_remainingPosts == 1 ? '' : 's'} remaining. Upgrade to Vendor Pro for unlimited popups!'
                    : 'You have $_remainingPosts popup${_remainingPosts == 1 ? '' : 's'} remaining this month. Upgrade to Organizer Pro for unlimited posts!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => _navigateToUpgrade(userType),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUpgradeTitle(String userType) {
    switch (userType) {
      case 'market_organizer':
        return 'Upgrade to Unlimited Vendor Posts';
      default:
        return 'Unlock Premium Features';
    }
  }

  String _getUpgradeDescription(String userType) {
    switch (userType) {
      case 'market_organizer':
        return 'You\'ve reached your monthly limit for vendor recruitment posts. Upgrade to Organizer Pro for unlimited posts and advanced vendor matching tools.';
      default:
        return 'Unlock unlimited popup creation and advanced features to grow your business faster.';
    }
  }

  List<String> _getUpgradeBenefits(String userType) {
    switch (userType) {
      case 'market_organizer':
        return [
          'Unlimited vendor recruitment posts',
          'Advanced vendor matching algorithms',
          'Response management tools',
          'Market performance analytics',
        ];
      case 'vendor':
        return [
          'Unlimited market applications',
          'Advanced business analytics',
          'Revenue optimization insights',
          'Priority customer support',
        ];
      default:
        return [
          'Unlimited features',
          'Advanced analytics',
          'Priority support',
          'Growth tools',
        ];
    }
  }

  String _getPremiumTierName(String userType) {
    switch (userType) {
      case 'market_organizer':
        return 'Organizer Pro';
      case 'vendor':
        return 'Vendor Pro';
      default:
        return 'Premium';
    }
  }

  void _navigateToUpgrade(String userType) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      String tier = userType == 'market_organizer' ? 'organizer' : 'vendor';
      context.push('/premium/upgrade?tier=$tier&userId=${currentUser.uid}');
    }
  }

  void _showUpgradeDetails(String userType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_getPremiumTierName(userType)} Benefits'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upgrade to unlock powerful features:',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ..._getDetailedBenefits(userType).map((benefit) =>
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          benefit,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPricingInfo(userType),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToUpgrade(userType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  List<String> _getDetailedBenefits(String userType) {
    switch (userType) {
      case 'market_organizer':
        return [
          'Unlimited "Looking for Vendors" posts per month',
          'Advanced vendor recruitment algorithms',
          'Comprehensive response management system',
          'Market performance analytics and insights',
          'Priority vendor matching and notifications',
          'Post performance tracking and optimization',
          'Vendor application insights and demographics',
          'Priority customer support and success team',
        ];
      case 'vendor':
        return [
          'Unlimited market applications per month',
          'Full vendor analytics dashboard',
          'Product performance tracking',
          'Revenue optimization recommendations',
          'Customer acquisition analysis',
          'Market expansion insights',
          'Seasonal business planning tools',
          'Priority customer support',
        ];
      default:
        return [
          'All premium features unlocked',
          'Advanced analytics and insights',
          'Priority customer support',
          'Growth optimization tools',
        ];
    }
  }

  String _getPricingInfo(String userType) {
    switch (userType) {
      case 'market_organizer':
        return 'Starting at \$69/month. Cancel anytime. 14-day free trial available.';
      case 'vendor':
        return 'Starting at \$29/month. Cancel anytime. 30-day free trial available.';
      default:
        return 'Affordable monthly plans. Cancel anytime.';
    }
  }

  // Removed _buildMarketPicker - vendors use SelectMarketScreen flow
  /*
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
  */

  Future<void> _savePost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if user can create posts before validation
    if (!_canCreatePost) {
      _showUpgradeDialog();
      return;
    }

    // Check monthly limit for ALL post types (3 total per month for free vendors)
    final canCreatePost = await _checkMonthlyPostLimit();
    if (!canCreatePost) {
      return; // Error message already shown in _checkMonthlyPostLimit
    }

    // For market posts, dates are handled by the market schedule
    if (_popupType == 'market' && _selectedMarket != null) {
      // Auto-fill date/time if not already set
      if (_selectedStartDateTime == null || _selectedEndDateTime == null) {
        _prefillMarketTime(_selectedMarket!);
        // If still no time after prefill, use next market day
        if (_selectedStartDateTime == null || _selectedEndDateTime == null) {
          final nextMarketDay = _getNextMarketDay(_selectedMarket!);
          if (nextMarketDay != null) {
            _selectedStartDateTime = nextMarketDay['start'];
            _selectedEndDateTime = nextMarketDay['end'];
          } else {
            // Fallback to next occurrence with default times
            final tomorrow = DateTime.now().add(const Duration(days: 1));
            _selectedStartDateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
            _selectedEndDateTime = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 14, 0);
          }
        }
      }
    } else {
      // For independent posts, validate location and times
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
          productListIds: _selectedProductLists.map((list) => list.id).toList(),
          vendorNotes: _vendorNotesController.text.trim().isNotEmpty 
              ? _vendorNotesController.text.trim() 
              : null,
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
        // Determine post type based on whether a market is selected
        final postType = (_selectedMarket != null && _popupType == 'market') 
            ? PostType.market 
            : PostType.independent;
        
        // Set approval status for market posts
        final approvalStatus = postType == PostType.market 
            ? ApprovalStatus.pending 
            : null;
        
        debugPrint('Creating post with type: ${postType.value}, marketId: ${_selectedMarket?.id}, approvalStatus: ${approvalStatus?.value}');
        
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
          postType: postType,
          approvalStatus: approvalStatus,
          approvalRequestedAt: postType == PostType.market ? now : null,
          associatedMarketId: _selectedMarket?.id,
          associatedMarketName: _selectedMarket?.name,
          productListIds: _selectedProductLists.map((list) => list.id).toList(),
          vendorNotes: _vendorNotesController.text.trim().isNotEmpty 
              ? _vendorNotesController.text.trim() 
              : null,
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
              productListIds: _selectedProductLists.map((list) => list.id).toList(),
            );
            await widget.postsRepository.updatePost(finalPost);
          }
        }
        
        if (mounted) {
          // Track successful post creation
          await _trackPostCreationSuccess(postType, _selectedMarket?.id);
          
          // Update visual cues to reflect new post count
          await _checkSubscriptionLimits();
          
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

  void _showUpgradeDialog() {
    final userType = _subscriptionInfo?['userType'] ?? 'vendor';
    
    // Track when users view upgrade options from limit dialog
    _trackUpgradeDialogViewed(userType);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.star,
              color: Colors.purple.shade600,
              size: 28,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _getUpgradeTitle(userType),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getUpgradeDescription(userType),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_getPremiumTierName(userType)} Benefits:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._getUpgradeBenefits(userType).map((benefit) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                benefit,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPricingInfo(userType),
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _trackUpgradeFromLimitDialog(userType);
              _navigateToUpgrade(userType);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            child: Text('Upgrade to ${_getPremiumTierName(userType)}'),
          ),
        ],
      ),
    );
  }

  /// Get current monthly post count for any user (vendor or organizer)
  Future<int> _getCurrentMonthlyPostCount(String userId) async {
    try {
      final statsRef = FirebaseFirestore.instance.collection('user_stats').doc(userId);
      final statsDoc = await statsRef.get();
      
      if (!statsDoc.exists) {
        return 0; // No posts created yet
      }
      
      final data = statsDoc.data()!;
      final currentMonth = _getCurrentMonth();
      final storedMonth = data['currentCountMonth'] as String?;
      
      if (storedMonth != currentMonth) {
        return 0; // Different month, count has reset
      }
      
      return (data['monthlyPostCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error getting monthly post count: $e');
      return 0; // Default to 0 on error
    }
  }

  /// Check if user can create a market post based on monthly limits
  Future<bool> _checkMonthlyPostLimit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Check if user is premium
      final userDoc = await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final isPremium = userData['isPremium'] ?? false;
      
      // Premium users have unlimited posts
      if (isPremium) return true;
      
      // Free users: check monthly limit
      final currentCount = await _getCurrentMonthlyPostCount(user.uid);
      const monthlyLimit = 3;
      
      if (currentCount >= monthlyLimit) {
        if (mounted) {
          // Get user type for appropriate messaging
          final userDoc = await FirebaseFirestore.instance
              .collection('user_profiles')
              .doc(user.uid)
              .get();
          final userType = userDoc.data()?['userType'] ?? 'vendor';
          
          // Track monthly limit encounter
          await _trackMonthlyLimitEncounter(currentCount, monthlyLimit, userType);
          
          final upgradeType = userType == 'market_organizer' ? 'organizer' : 'vendor';
          final productName = userType == 'market_organizer' ? 'Organizer Pro' : 'Vendor Pro';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('You\'ve reached your monthly limit of $monthlyLimit posts. Upgrade to $productName for unlimited posts.'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Upgrade',
                textColor: Colors.white,
                onPressed: () {
                  _trackUpgradeFromLimitDialog(upgradeType);
                  _navigateToUpgrade(upgradeType);
                },
              ),
            ),
          );
        }
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking monthly post limit: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking post limit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  // Analytics tracking methods
  
  Future<void> _trackPostCreationStart() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final userType = _currentUserProfile?.userType ?? 'vendor';
    final isPremium = _subscriptionInfo?['isPremium'] ?? false;
    
    await RealTimeAnalyticsService.trackEvent('post_creation_started', {
      'userId': currentUser.uid,
      'userType': userType,
      'isPremium': isPremium,
      'screenContext': widget.editingPost != null ? 'edit' : 'create',
      'startTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackPostTypeSelection(String? postType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || postType == null) return;
    
    final userType = _currentUserProfile?.userType ?? 'vendor';
    final isPremium = _subscriptionInfo?['isPremium'] ?? false;
    
    await RealTimeAnalyticsService.trackEvent('post_type_selected', {
      'userId': currentUser.uid,
      'userType': userType,
      'isPremium': isPremium,
      'selectedPostType': postType,
      'selectionTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackPostCreationSuccess(PostType postType, String? marketId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final userType = _currentUserProfile?.userType ?? 'vendor';
    final isPremium = _subscriptionInfo?['isPremium'] ?? false;
    
    await RealTimeAnalyticsService.trackEvent('post_creation_completed', {
      'userId': currentUser.uid,
      'userType': userType,
      'isPremium': isPremium,
      'postType': postType.value,
      'marketId': marketId,
      'hasPhotos': _selectedPhotos.isNotEmpty,
      'hasProductLists': _selectedProductLists.isNotEmpty,
      'requiresApproval': postType == PostType.market,
      'completionTime': DateTime.now().toIso8601String(),
      'remainingPosts': _remainingPosts,
    });
  }
  
  Future<void> _trackMonthlyLimitEncounter(int currentCount, int limit, String userType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('monthly_limit_encountered', {
      'userId': currentUser.uid,
      'userType': userType,
      'currentPostCount': currentCount,
      'monthlyLimit': limit,
      'encounterTime': DateTime.now().toIso8601String(),
      'attemptedPostType': _popupType ?? 'unknown',
    });
  }
  
  Future<void> _trackUpgradeDialogViewed(String userType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('upgrade_dialog_viewed', {
      'userId': currentUser.uid,
      'userType': userType,
      'viewSource': 'monthly_limit',
      'remainingPosts': _remainingPosts,
      'viewTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackUpgradeFromLimitDialog(String userType) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('upgrade_clicked_from_limit', {
      'userId': currentUser.uid,
      'userType': userType,
      'clickSource': 'monthly_limit_dialog',
      'remainingPosts': _remainingPosts,
      'clickTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackPostCreationAbandonment() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final userType = _currentUserProfile?.userType ?? 'vendor';
    final isPremium = _subscriptionInfo?['isPremium'] ?? false;
    
    // Calculate abandonment stage
    String abandonmentStage = 'initial';
    if (_vendorNameController.text.isNotEmpty) {
      abandonmentStage = 'business_name_entered';
    }
    if (_locationController.text.isNotEmpty || _selectedMarket != null) {
      abandonmentStage = 'location_selected';
    }
    if (_descriptionController.text.isNotEmpty) {
      abandonmentStage = 'description_entered';
    }
    if (_selectedStartDateTime != null) {
      abandonmentStage = 'datetime_selected';
    }
    if (_selectedPhotos.isNotEmpty) {
      abandonmentStage = 'photos_added';
    }
    
    await RealTimeAnalyticsService.trackEvent('post_creation_abandoned', {
      'userId': currentUser.uid,
      'userType': userType,
      'isPremium': isPremium,
      'abandonmentStage': abandonmentStage,
      'postType': _popupType ?? 'unknown',
      'selectedMarketId': _selectedMarket?.id,
      'hasBusinessName': _vendorNameController.text.isNotEmpty,
      'hasLocation': _locationController.text.isNotEmpty || _selectedMarket != null,
      'hasDescription': _descriptionController.text.isNotEmpty,
      'hasDateTime': _selectedStartDateTime != null,
      'hasPhotos': _selectedPhotos.isNotEmpty,
      'hasProductLists': _selectedProductLists.isNotEmpty,
      'remainingPosts': _remainingPosts,
      'canCreatePost': _canCreatePost,
      'isNearLimit': _isNearLimit,
      'abandonmentTime': DateTime.now().toIso8601String(),
      'screenContext': widget.editingPost != null ? 'edit' : 'create',
    });
  }
  
  Future<void> _trackFormFieldInteraction(String fieldName, dynamic value) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('form_field_interaction', {
      'userId': currentUser.uid,
      'userType': _currentUserProfile?.userType ?? 'vendor',
      'fieldName': fieldName,
      'hasValue': value != null && value.toString().isNotEmpty,
      'postType': _popupType ?? 'unknown',
      'remainingPosts': _remainingPosts,
      'interactionTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackMarketSelection(String? marketId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('market_selection_changed', {
      'userId': currentUser.uid,
      'userType': _currentUserProfile?.userType ?? 'vendor',
      'selectedMarketId': marketId,
      'previousMarketId': _selectedMarket?.id,
      'selectionSource': marketId != null ? 'market_chosen' : 'independent_chosen',
      'selectionTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackDateTimeSelection(DateTime? dateTime, String type) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('datetime_selection', {
      'userId': currentUser.uid,
      'userType': _currentUserProfile?.userType ?? 'vendor',
      'dateTimeType': type, // 'start' or 'end'
      'selectedDateTime': dateTime?.toIso8601String(),
      'postType': _popupType ?? 'unknown',
      'marketId': _selectedMarket?.id,
      'selectionTime': DateTime.now().toIso8601String(),
    });
  }
  
  Future<void> _trackPhotoUploadInteraction(List<File> photos) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    await RealTimeAnalyticsService.trackEvent('photo_upload_interaction', {
      'userId': currentUser.uid,
      'userType': _currentUserProfile?.userType ?? 'vendor',
      'photoCount': photos.length,
      'isPremium': _subscriptionInfo?['isPremium'] ?? false,
      'postType': _popupType ?? 'unknown',
      'uploadTime': DateTime.now().toIso8601String(),
    });
  }
}