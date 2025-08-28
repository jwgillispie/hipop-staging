import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../blocs/auth/auth_bloc.dart';
import '../../../../blocs/auth/auth_state.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../market/models/market.dart';
import '../../../shared/widgets/common/simple_places_widget.dart';
import '../../../shared/services/places_service.dart';
import '../../../../core/theme/hipop_colors.dart';
import '../../../premium/screens/subscription_management_screen.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _eventWebsiteController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _ticketUrlController = TextEditingController();
  
  // Form state
  DateTime _startDateTime = DateTime.now().add(const Duration(days: 1));
  DateTime _endDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
  Market? _selectedMarket;
  final List<Market> _availableMarkets = [];
  bool _isLoading = false;
  
  // Location selection with Google Places
  PlaceDetails? _selectedPlace;
  String _selectedAddress = '';
  
  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _eventWebsiteController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _ticketUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets() async {
    // For now, we'll skip market loading since the association isn't implemented
    // This can be added later when market-organizer association is implemented
  }

  void _onPlaceSelected(PlaceDetails place) {
    setState(() {
      _selectedPlace = place;
      _selectedAddress = place.formattedAddress;
    });
  }

  void _onAddressCleared() {
    setState(() {
      _selectedPlace = null;
      _selectedAddress = '';
    });
  }

  Map<String, String> _parseAddressComponents(String formattedAddress) {
    // Simple parsing of formatted address
    // Expected format: "Street Address, City, State ZIP, Country"
    final parts = formattedAddress.split(', ');
    
    if (parts.length >= 3) {
      final address = parts[0];
      final city = parts[1];
      final stateZip = parts[2].split(' ');
      final state = stateZip.isNotEmpty ? stateZip[0] : '';
      
      return {
        'address': address,
        'city': city,
        'state': state,
      };
    }
    
    // Fallback: use the full formatted address as address
    return {
      'address': formattedAddress,
      'city': '',
      'state': '',
    };
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDateTime : _endDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: HiPopColors.primaryDeepSage,
              onPrimary: Colors.white,
              surface: HiPopColors.darkSurface,
              onSurface: HiPopColors.darkTextPrimary,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: HiPopColors.darkSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null && mounted) {
      if (!context.mounted) return;
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartDate ? _startDateTime : _endDateTime),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: HiPopColors.primaryDeepSage,
                onPrimary: Colors.white,
                surface: HiPopColors.darkSurface,
                onSurface: HiPopColors.darkTextPrimary,
              ),
              dialogTheme: const DialogThemeData(
                backgroundColor: HiPopColors.darkSurface,
              ),
              timePickerTheme: const TimePickerThemeData(
                backgroundColor: HiPopColors.darkSurface,
                dialBackgroundColor: HiPopColors.darkSurfaceVariant,
                hourMinuteColor: HiPopColors.darkSurfaceVariant,
                hourMinuteTextColor: HiPopColors.darkTextPrimary,
                dialHandColor: HiPopColors.primaryDeepSage,
                dialTextColor: HiPopColors.darkTextPrimary,
                entryModeIconColor: HiPopColors.darkTextSecondary,
                dayPeriodBorderSide: BorderSide(color: HiPopColors.darkBorder),
                dayPeriodTextColor: HiPopColors.darkTextPrimary,
              ),
            ),
            child: child!,
          );
        },
      );
      
      if (pickedTime != null && mounted) {
        setState(() {
          final newDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          
          if (isStartDate) {
            _startDateTime = newDateTime;
            // Ensure end date is after start date
            if (_endDateTime.isBefore(_startDateTime)) {
              _endDateTime = _startDateTime.add(const Duration(hours: 2));
            }
          } else {
            _endDateTime = newDateTime;
          }
        });
      }
    }
  }

  Future<void> _createEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    // Check if organizer can create event
    final canCreate = await EventService.canOrganizerCreateEvent(authState.user.uid);
    if (!canCreate) {
      if (!mounted) return;
      _showEventLimitDialog();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_selectedPlace == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a location for the event'),
            backgroundColor: HiPopColors.errorPlum,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final addressComponents = _parseAddressComponents(_selectedPlace!.formattedAddress);
      
      final event = Event(
        id: '', // Will be set by Firestore
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _selectedPlace!.formattedAddress,
        address: addressComponents['address'] ?? _selectedPlace!.formattedAddress,
        city: addressComponents['city'] ?? '',
        state: addressComponents['state'] ?? '',
        latitude: _selectedPlace!.latitude,
        longitude: _selectedPlace!.longitude,
        startDateTime: _startDateTime,
        endDateTime: _endDateTime,
        organizerId: authState.user.uid,
        organizerName: authState.userProfile?.businessName ?? 
                     authState.userProfile?.organizationName ?? 
                     authState.user.email ?? 'Unknown',
        marketId: _selectedMarket?.id,
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        imageUrl: '',
        links: const [],
        eventWebsite: _eventWebsiteController.text.trim().isNotEmpty 
            ? _eventWebsiteController.text.trim() 
            : null,
        instagramUrl: _instagramController.text.trim().isNotEmpty 
            ? 'https://instagram.com/${_instagramController.text.replaceAll('@', '').trim()}' 
            : null,
        facebookUrl: _facebookController.text.trim().isNotEmpty 
            ? _facebookController.text.trim() 
            : null,
        ticketUrl: _ticketUrlController.text.trim().isNotEmpty 
            ? _ticketUrlController.text.trim() 
            : null,
        additionalLinks: null,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await EventService.createEvent(event);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event created successfully!')),
        );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // Check if it's a limit exception
      if (e is EventLimitException) {
        _showEventLimitDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating event: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showEventLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkBackground,
        title: Row(
          children: [
            Icon(Icons.warning, color: HiPopColors.warningAmber),
            const SizedBox(width: 8),
            const Text(
              'Event Limit Reached',
              style: TextStyle(color: HiPopColors.darkTextPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have reached your monthly limit of 1 event.',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.primaryDeepSage.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: HiPopColors.primaryDeepSage),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: HiPopColors.primaryDeepSage, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Unlimited events per month\n'
                    '• Advanced event features\n'
                    '• Priority support\n'
                    '• Analytics & insights',
                    style: TextStyle(
                      fontSize: 14,
                      color: HiPopColors.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Get current user ID from auth state
              final authState = context.read<AuthBloc>().state;
              if (authState is Authenticated) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => SubscriptionManagementScreen(
                      userId: authState.user.uid,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.primaryDeepSage,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HiPopColors.darkBackground,
      appBar: AppBar(
        title: const Text('Create Event'),
        backgroundColor: HiPopColors.darkSurface,
        foregroundColor: HiPopColors.darkTextPrimary,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _isLoading ? null : _createEvent,
              style: TextButton.styleFrom(
                foregroundColor: HiPopColors.primaryDeepSage,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(HiPopColors.primaryDeepSage),
                      ),
                    )
                  : const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Event Name
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: HiPopColors.darkTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Event Name *',
                  labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                  hintText: 'Enter event name',
                  hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.event, color: HiPopColors.darkTextSecondary),
                  filled: true,
                  fillColor: HiPopColors.darkSurfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.errorPlum),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.errorPlum, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Event name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                style: const TextStyle(color: HiPopColors.darkTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                  hintText: 'Describe your event',
                  hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.description, color: HiPopColors.darkTextSecondary),
                  filled: true,
                  fillColor: HiPopColors.darkSurfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                  ),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Date and Time Section
              Card(
                color: HiPopColors.darkSurface,
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Schedule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Start Date/Time
                      Material(
                        color: HiPopColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _selectDateTime(context, true),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: HiPopColors.darkBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule, color: HiPopColors.darkTextSecondary),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Start Date & Time',
                                        style: TextStyle(
                                          color: HiPopColors.darkTextSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('MMM d, yyyy - h:mm a').format(_startDateTime),
                                        style: const TextStyle(
                                          color: HiPopColors.darkTextPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: HiPopColors.darkTextSecondary, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // End Date/Time
                      Material(
                        color: HiPopColors.darkSurfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _selectDateTime(context, false),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: HiPopColors.darkBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.schedule, color: HiPopColors.darkTextSecondary),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'End Date & Time',
                                        style: TextStyle(
                                          color: HiPopColors.darkTextSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        DateFormat('MMM d, yyyy - h:mm a').format(_endDateTime),
                                        style: const TextStyle(
                                          color: HiPopColors.darkTextPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, color: HiPopColors.darkTextSecondary, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location Section
              Card(
                color: HiPopColors.darkSurface,
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: HiPopColors.darkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: HiPopColors.darkSurfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: HiPopColors.darkBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: HiPopColors.darkBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                            ),
                            labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                            hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                          ),
                          textTheme: const TextTheme(
                            bodyLarge: TextStyle(color: HiPopColors.darkTextPrimary),
                          ),
                        ),
                        child: SimplePlacesWidget(
                          initialLocation: _selectedAddress,
                          onLocationSelected: (PlaceDetails? place) {
                            if (place != null) {
                              _onPlaceSelected(place);
                            } else {
                              _onAddressCleared();
                            }
                          },
                        ),
                      ),
                      if (_selectedPlace != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: HiPopColors.successGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: HiPopColors.successGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: HiPopColors.successGreenDark, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Location selected: ${_selectedPlace!.formattedAddress}',
                                  style: const TextStyle(
                                    color: HiPopColors.successGreenDark,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Market Association
              if (_availableMarkets.isNotEmpty) ...[
                Card(
                  color: HiPopColors.darkSurface,
                  elevation: 2,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Market Association',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: HiPopColors.darkTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Market>(
                          value: _selectedMarket,
                          dropdownColor: HiPopColors.darkSurfaceVariant,
                          style: const TextStyle(color: HiPopColors.darkTextPrimary),
                          decoration: InputDecoration(
                            labelText: 'Associate with Market (Optional)',
                            labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                            prefixIcon: const Icon(Icons.store, color: HiPopColors.darkTextSecondary),
                            filled: true,
                            fillColor: HiPopColors.darkSurfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: HiPopColors.darkBorder),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: HiPopColors.darkBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<Market>(
                              value: null,
                              child: Text('No market association'),
                            ),
                            ..._availableMarkets.map((market) => DropdownMenuItem(
                              value: market,
                              child: Text(market.name),
                            )),
                          ],
                          onChanged: (Market? value) {
                            setState(() {
                              _selectedMarket = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Tags
              TextFormField(
                controller: _tagsController,
                style: const TextStyle(color: HiPopColors.darkTextPrimary),
                decoration: InputDecoration(
                  labelText: 'Tags (Optional)',
                  labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                  hintText: 'Enter tags separated by commas',
                  hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                  prefixIcon: const Icon(Icons.tag, color: HiPopColors.darkTextSecondary),
                  helperText: 'Example: festival, food, community',
                  helperStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.7)),
                  filled: true,
                  fillColor: HiPopColors.darkSurfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.darkBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.darkBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Event Links Section
              Card(
                color: HiPopColors.darkSurface,
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: HiPopColors.darkBorder.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.link, color: HiPopColors.primaryDeepSage),
                          const SizedBox(width: 8),
                          Text(
                            'Event Links & Social Media',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add links to help vendors and shoppers learn more about this event',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: HiPopColors.darkTextSecondary.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Event Website
                      TextFormField(
                        controller: _eventWebsiteController,
                        style: const TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Event Website',
                          labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: const Icon(Icons.language, color: HiPopColors.darkTextSecondary),
                          hintText: 'https://yourevent.com',
                          hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: HiPopColors.darkSurfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.startsWith('http://') && !value.startsWith('https://')) {
                              return 'Please enter a valid URL starting with http:// or https://';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Instagram Handle
                      TextFormField(
                        controller: _instagramController,
                        style: const TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Instagram',
                          labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: Container(
                            padding: const EdgeInsets.all(12),
                            child: Image.asset(
                              'assets/icons/instagram.png',
                              width: 24,
                              height: 24,
                              color: HiPopColors.darkTextSecondary,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.camera_alt, color: HiPopColors.darkTextSecondary, size: 24);
                              },
                            ),
                          ),
                          prefixText: '@',
                          prefixStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                          hintText: 'yourevent',
                          hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: HiPopColors.darkSurfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum, width: 2),
                          ),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            // Remove @ if user included it
                            value = value.replaceAll('@', '');
                            if (value.contains(' ')) {
                              return 'Instagram handle cannot contain spaces';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value)) {
                              return 'Invalid Instagram handle format';
                            }
                          }
                          return null;
                        },
                        onChanged: (value) {
                          // Remove @ symbol if user types it
                          if (value.startsWith('@')) {
                            _instagramController.text = value.substring(1);
                            _instagramController.selection = TextSelection.fromPosition(
                              TextPosition(offset: _instagramController.text.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Facebook Event Page
                      TextFormField(
                        controller: _facebookController,
                        style: const TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Facebook Event',
                          labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: const Icon(Icons.facebook, color: HiPopColors.darkTextSecondary),
                          hintText: 'https://facebook.com/events/...',
                          hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                          filled: true,
                          fillColor: HiPopColors.darkSurfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.contains('facebook.com') && !value.contains('fb.com')) {
                              return 'Please enter a valid Facebook URL';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      
                      // Ticket/Registration URL
                      TextFormField(
                        controller: _ticketUrlController,
                        style: const TextStyle(color: HiPopColors.darkTextPrimary),
                        decoration: InputDecoration(
                          labelText: 'Ticket/Registration Link',
                          labelStyle: const TextStyle(color: HiPopColors.darkTextSecondary),
                          prefixIcon: const Icon(Icons.confirmation_number, color: HiPopColors.darkTextSecondary),
                          hintText: 'https://eventbrite.com/...',
                          hintStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.5)),
                          helperText: 'Link for ticket purchase or event registration',
                          helperStyle: TextStyle(color: HiPopColors.darkTextSecondary.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: HiPopColors.darkSurfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.darkBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.primaryDeepSage, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: HiPopColors.errorPlum, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (!value.startsWith('http://') && !value.startsWith('https://')) {
                              return 'Please enter a valid URL starting with http:// or https://';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Create Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HiPopColors.primaryDeepSage,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Create Event',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}