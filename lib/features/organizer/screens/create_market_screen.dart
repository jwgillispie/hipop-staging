import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_event.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/premium/services/subscription_service.dart';
import 'package:hipop/features/shared/services/places_service.dart';
import 'package:hipop/features/shared/widgets/common/unified_location_search.dart';
import 'package:hipop/features/shared/services/photo_service.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';

class CreateMarketScreen extends StatefulWidget {
  const CreateMarketScreen({super.key});

  @override
  State<CreateMarketScreen> createState() => _CreateMarketScreenState();
}

class _CreateMarketScreenState extends State<CreateMarketScreen> {
  // Form data
  final Map<String, dynamic> _formData = {};
  final Map<String, bool> _completedFields = {};
  
  // Required fields
  final List<String> _requiredFields = [
    'name',
    'location',
    'marketDate',
    'operatingHours',
  ];
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  
  // Premium fields
  final List<String> _premiumFields = [
    'lookingForVendors',
  ];
  
  bool _isLoading = false;
  bool _hasAccess = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    
    // Initialize form data listeners
    _nameController.addListener(() {
      setState(() {
        _formData['name'] = _nameController.text;
        _completedFields['name'] = _nameController.text.trim().isNotEmpty;
      });
    });
    
    _descriptionController.addListener(() {
      setState(() {
        _formData['description'] = _descriptionController.text;
      });
    });
    
    _instagramController.addListener(() {
      setState(() {
        _formData['instagram'] = _instagramController.text;
      });
    });
    
    _websiteController.addListener(() {
      setState(() {
        _formData['website'] = _websiteController.text;
      });
    });
  }
  
  Future<void> _checkPremiumStatus() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      final subscription = await SubscriptionService.getUserSubscription(authState.user.uid);
      setState(() {
        _isPremium = subscription != null && subscription.isActive;
      });
    }
  }
  
  int get _completedRequiredCount {
    return _requiredFields.where((field) => _completedFields[field] == true).length;
  }
  
  bool get _canCreateMarket {
    return _requiredFields.every((field) => _completedFields[field] == true);
  }
  
  String _getProgressText() {
    return '$_completedRequiredCount of ${_requiredFields.length} required fields completed';
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: HiPopColors.darkTextTertiary,
        ),
      ),
    );
  }
  
  
  void _showPremiumDialog() {
    final authState = context.read<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        title: Text(
          '💎 Premium Feature',
          style: TextStyle(color: HiPopColors.darkTextPrimary),
        ),
        content: Text(
          'This feature is available for premium users. Upgrade to unlock vendor recruitment tools and more!',
          style: TextStyle(color: HiPopColors.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (user != null) {
                context.go('/premium/upgrade?tier=marketOrganizerPremium&userId=${user.uid}');
              } else {
                context.push('/premium/onboarding');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.premiumGold,
              foregroundColor: HiPopColors.darkBackground,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }
  
  
  
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  Widget _buildInlineTextField({
    required String fieldKey,
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              Text(
                '*',
                style: TextStyle(
                  color: HiPopColors.errorPlum,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: HiPopColors.darkTextPrimary),
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
            filled: true,
            fillColor: HiPopColors.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateField() {
    final selectedDate = _formData['marketDate'] as DateTime?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Market Date',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.dark(
                      primary: HiPopColors.organizerAccent,
                      onPrimary: HiPopColors.darkTextPrimary,
                      surface: HiPopColors.darkSurface,
                      onSurface: HiPopColors.darkTextPrimary,
                      surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
                      onSurfaceVariant: HiPopColors.darkTextSecondary,
                      secondary: HiPopColors.organizerAccent,
                      onSecondary: HiPopColors.darkTextPrimary,
                      error: HiPopColors.errorPlum,
                      onError: HiPopColors.darkTextPrimary,
                      outline: HiPopColors.darkBorder,
                      shadow: HiPopColors.darkShadow,
                    ),
                    dialogTheme: DialogThemeData(
                      backgroundColor: HiPopColors.darkSurface,
                      surfaceTintColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    datePickerTheme: DatePickerThemeData(
                      backgroundColor: HiPopColors.darkSurface,
                      surfaceTintColor: Colors.transparent,
                      headerBackgroundColor: HiPopColors.darkSurfaceVariant,
                      headerForegroundColor: HiPopColors.darkTextPrimary,
                      weekdayStyle: TextStyle(color: HiPopColors.darkTextSecondary),
                      dayStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                      yearStyle: TextStyle(color: HiPopColors.darkTextPrimary),
                      todayBackgroundColor: WidgetStateProperty.all(HiPopColors.darkSurfaceElevated),
                      todayForegroundColor: WidgetStateProperty.all(HiPopColors.organizerAccent),
                      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.organizerAccent;
                        }
                        return null;
                      }),
                      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.darkTextPrimary;
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return HiPopColors.darkTextDisabled;
                        }
                        return HiPopColors.darkTextPrimary;
                      }),
                      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.organizerAccent;
                        }
                        return null;
                      }),
                      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return HiPopColors.darkTextPrimary;
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return HiPopColors.darkTextDisabled;
                        }
                        return HiPopColors.darkTextPrimary;
                      }),
                      confirmButtonStyle: TextButton.styleFrom(
                        foregroundColor: HiPopColors.organizerAccent,
                      ),
                      cancelButtonStyle: TextButton.styleFrom(
                        foregroundColor: HiPopColors.darkTextSecondary,
                      ),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              setState(() {
                _formData['marketDate'] = date;
                _completedFields['marketDate'] = true;
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              border: Border.all(color: HiPopColors.darkBorder),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: HiPopColors.organizerAccent),
                const SizedBox(width: 12),
                Text(
                  selectedDate != null 
                    ? '${selectedDate.month}/${selectedDate.day}/${selectedDate.year}'
                    : 'Select market date',
                  style: TextStyle(
                    color: selectedDate != null 
                      ? HiPopColors.darkTextPrimary
                      : HiPopColors.darkTextTertiary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTimeFields() {
    final startTime = _formData['startTime'] as TimeOfDay? ?? const TimeOfDay(hour: 9, minute: 0);
    final endTime = _formData['endTime'] as TimeOfDay? ?? const TimeOfDay(hour: 14, minute: 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Start Time
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (time != null) {
                    setState(() {
                      _formData['startTime'] = time;
                      _updateOperatingHoursCompletion();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    border: Border.all(color: HiPopColors.darkBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: HiPopColors.organizerAccent),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeOfDay(startTime),
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'to',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 16),
            // End Time
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (time != null) {
                    setState(() {
                      _formData['endTime'] = time;
                      _updateOperatingHoursCompletion();
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurface,
                    border: Border.all(color: HiPopColors.darkBorder),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, color: HiPopColors.organizerAccent),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeOfDay(endTime),
                        style: TextStyle(
                          color: HiPopColors.darkTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  void _updateOperatingHoursCompletion() {
    final hasStartTime = _formData['startTime'] != null;
    final hasEndTime = _formData['endTime'] != null;
    _completedFields['operatingHours'] = hasStartTime && hasEndTime;
    
    if (hasStartTime && hasEndTime) {
      _formData['operatingHours'] = '${_formatTimeOfDay(_formData['startTime'])} - ${_formatTimeOfDay(_formData['endTime'])}';
    }
  }
  
  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '*',
              style: TextStyle(
                color: HiPopColors.errorPlum,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        UnifiedLocationSearch(
          hintText: 'Search for market location...',
          initialLocation: _formData['address'],
          textStyle: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 16,
          ),
          onPlaceSelected: (placeDetails) {
            setState(() {
              _formData['location'] = placeDetails;
              _formData['address'] = placeDetails.formattedAddress;
              _completedFields['location'] = true;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search for market location...',
            hintStyle: TextStyle(color: HiPopColors.darkTextTertiary),
            filled: true,
            fillColor: HiPopColors.darkSurface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: HiPopColors.organizerAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildVendorToggle() {
    final isEnabled = _formData['lookingForVendors'] ?? false;
    
    return Card(
      color: HiPopColors.darkSurface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: HiPopColors.darkBorder.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: HiPopColors.premiumGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.campaign,
                color: HiPopColors.premiumGold,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Looking for Vendors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: HiPopColors.premiumGold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '💎 PREMIUM',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.premiumGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled ? 'Vendor recruitment enabled' : 'Enable vendor recruitment',
                    style: TextStyle(
                      fontSize: 14,
                      color: isEnabled 
                        ? HiPopColors.successGreen
                        : HiPopColors.darkTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isEnabled,
              activeColor: HiPopColors.premiumGold,
              onChanged: (value) {
                if (!_isPremium) {
                  _showPremiumDialog();
                  return;
                }
                setState(() {
                  _formData['lookingForVendors'] = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  
  Future<void> _createMarket() async {
    setState(() => _isLoading = true);
    
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) {
        throw Exception('User not authenticated');
      }
      
      final location = _formData['location'] as PlaceDetails?;
      if (location == null) {
        throw Exception('Location is required');
      }
      
      // Parse address components
      final addressComponents = location.formattedAddress.split(', ');
      final address = addressComponents[0];
      final city = addressComponents.length > 1 ? addressComponents[1] : '';
      final stateAndZip = addressComponents.length > 2 ? addressComponents[2] : '';
      final state = stateAndZip.split(' ')[0];
      
      // Create market object
      final market = Market(
        id: '',
        name: _formData['name'] ?? 'New Market',
        address: address,
        city: city,
        state: state,
        latitude: location.latitude,
        longitude: location.longitude,
        description: _formData['description'],
        eventDate: _formData['marketDate'] ?? DateTime.now(),
        startTime: _formatTimeOfDay(_formData['startTime'] ?? const TimeOfDay(hour: 9, minute: 0)),
        endTime: _formatTimeOfDay(_formData['endTime'] ?? const TimeOfDay(hour: 14, minute: 0)),
        createdAt: DateTime.now(),
        associatedVendorIds: const [],
        flyerUrls: const [],
        isActive: true,
        isLookingForVendors: _formData['lookingForVendors'] ?? false,
        applicationFee: 0, // Removed vendor fees
        dailyBoothFee: 0, // Removed vendor fees
        vendorSpotsTotal: null, // Removed vendor cap
        vendorSpotsAvailable: null, // Removed vendor cap
        instagramHandle: _formData['instagram'],
      );
      
      // Create market in Firestore
      final marketId = await MarketService.createMarket(market);
      
      // Associate market with user
      final userProfileService = UserProfileService();
      final updatedProfile = authState.userProfile!.addManagedMarket(marketId);
      await userProfileService.updateUserProfile(updatedProfile);
      
      // Refresh AuthBloc
      if (mounted) {
        context.read<AuthBloc>().add(ReloadUserEvent());
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Market created successfully!'),
            backgroundColor: HiPopColors.successGreen,
          ),
        );
        
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating market: $e'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instagramController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        backgroundColor: HiPopColors.darkSurface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: HiPopColors.darkTextPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Create New Market',
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: HiPopColors.darkBorder.withValues(alpha: 0.3)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _completedRequiredCount / _requiredFields.length,
                    backgroundColor: HiPopColors.darkBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      HiPopColors.successGreen,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  _getProgressText(),
                  style: TextStyle(
                    fontSize: 12,
                    color: HiPopColors.darkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 140, top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('BASIC INFORMATION'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInlineTextField(
                        fieldKey: 'name',
                        label: 'Market Name',
                        controller: _nameController,
                        hintText: 'e.g., Downtown Farmers Market',
                        isRequired: true,
                      ),
                      const SizedBox(height: 20),
                      _buildLocationField(),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'description',
                        label: 'Description',
                        controller: _descriptionController,
                        hintText: 'Describe your market...',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
                
                _buildSectionHeader('SCHEDULE & TIMING'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildDateField(),
                      const SizedBox(height: 20),
                      _buildTimeFields(),
                    ],
                  ),
                ),
                
                _buildSectionHeader('VENDOR MANAGEMENT'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildVendorToggle(),
                ),
                
                _buildSectionHeader('MARKETING'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildInlineTextField(
                        fieldKey: 'website',
                        label: 'Website',
                        controller: _websiteController,
                        hintText: 'https://example.com',
                      ),
                      const SizedBox(height: 20),
                      _buildInlineTextField(
                        fieldKey: 'instagram',
                        label: 'Instagram',
                        controller: _instagramController,
                        hintText: '@yourmarket',
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: HiPopColors.darkSurface,
                border: Border(
                  top: BorderSide(color: HiPopColors.darkBorder.withValues(alpha: 0.3)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getProgressText(),
                      style: TextStyle(
                        fontSize: 12,
                        color: HiPopColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _canCreateMarket && !_isLoading ? _createMarket : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HiPopColors.organizerAccent,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: HiPopColors.darkBorder,
                          disabledForegroundColor: HiPopColors.darkTextTertiary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Create Market',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}