import 'package:flutter/material.dart';
import '../models/market.dart';
import '../models/market_schedule.dart';
import '../models/vendor_application.dart';
import '../models/managed_vendor.dart';
import '../services/market_service.dart';
import '../services/places_service.dart';
import '../services/vendor_application_service.dart';
import '../services/managed_vendor_service.dart';
import '../widgets/market_schedule_form.dart';
import '../widgets/common/unified_location_search.dart';
import '../utils/ui_utils.dart';
import '../utils/constants.dart';

class MarketFormDialog extends StatefulWidget {
  final Market? market;

  const MarketFormDialog({super.key, this.market});

  @override
  State<MarketFormDialog> createState() => _MarketFormDialogState();
}

class _MarketFormDialogState extends State<MarketFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Address search using Google Places
  PlaceDetails? _selectedPlace;
  String _selectedAddress = '';

  // New schedule system
  List<MarketSchedule> _marketSchedules = [];
  
  // Vendor management
  List<VendorApplication> _approvedApplications = [];
  List<ManagedVendor> _existingManagedVendors = [];
  List<String> _selectedVendorIds = [];
  bool _isLoadingVendors = false;
  
  bool _isLoading = false;
  bool get _isEditing => widget.market != null;

  @override
  void initState() {
    super.initState();
    
    // If editing, populate fields
    if (_isEditing) {
      final market = widget.market!;
      _nameController.text = market.name;
      _selectedAddress = '${market.address}, ${market.city}, ${market.state}';
      _descriptionController.text = market.description ?? '';
      _selectedVendorIds = List.from(market.associatedVendorIds);
      
      // Create a PlaceDetails object from existing market data
      _selectedPlace = PlaceDetails(
        placeId: 'existing_${market.id}',
        name: market.address,
        formattedAddress: '${market.address}, ${market.city}, ${market.state}',
        latitude: market.latitude,
        longitude: market.longitude,
      );
      
      // Load existing schedules if available
      _loadExistingSchedules();
    }
    
    // Load vendor data
    _loadVendorData();
  }
  
  Future<void> _loadExistingSchedules() async {
    if (widget.market?.scheduleIds?.isNotEmpty == true) {
      try {
        // TODO: Load existing schedules from the scheduleIds
        // For now, we'll convert legacy operatingDays to schedule format
        _convertLegacyOperatingDays();
      } catch (e) {
        // If loading fails, fall back to legacy conversion
        _convertLegacyOperatingDays();
      }
    } else {
      // Convert legacy operating days to new schedule format
      _convertLegacyOperatingDays();
    }
  }
  
  void _convertLegacyOperatingDays() {
    if (widget.market?.operatingDays.isNotEmpty == true) {
      // Convert old operatingDays format to MarketSchedule
      final operatingDays = widget.market!.operatingDays;
      final daysOfWeek = <int>[];
      String? startTime;
      String? endTime;
      
      // Extract days and times from legacy format
      for (final entry in operatingDays.entries) {
        final dayIndex = _getDayIndex(entry.key);
        if (dayIndex != null) {
          daysOfWeek.add(dayIndex);
          
          // Parse time from format like "9AM-2PM"
          final times = _parseLegacyTimeString(entry.value);
          startTime ??= times['start'];
          endTime ??= times['end'];
        }
      }
      
      if (daysOfWeek.isNotEmpty && startTime != null && endTime != null) {
        _marketSchedules = [
          MarketSchedule.recurring(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            marketId: widget.market!.id,
            startTime: startTime,
            endTime: endTime,
            pattern: RecurrencePattern.weekly,
            daysOfWeek: daysOfWeek,
            startDate: DateTime.now(),
          ),
        ];
      }
    }
  }
  
  int? _getDayIndex(String dayKey) {
    switch (dayKey.toLowerCase()) {
      case 'monday': return 1;
      case 'tuesday': return 2;
      case 'wednesday': return 3;
      case 'thursday': return 4;
      case 'friday': return 5;
      case 'saturday': return 6;
      case 'sunday': return 7;
      default: return null;
    }
  }
  
  Map<String, String> _parseLegacyTimeString(String timeString) {
    // Parse strings like "9AM-2PM" or "9:00AM-2:00PM"
    final parts = timeString.split('-');
    if (parts.length == 2) {
      return {
        'start': _formatTime(parts[0].trim()),
        'end': _formatTime(parts[1].trim()),
      };
    }
    return {'start': '9:00 AM', 'end': '2:00 PM'};
  }
  
  String _formatTime(String timePart) {
    // Convert "9AM" or "9:00AM" to "9:00 AM"
    final regex = RegExp(r'(\d{1,2}):?(\d{0,2})(AM|PM)', caseSensitive: false);
    final match = regex.firstMatch(timePart);
    
    if (match != null) {
      final hour = match.group(1) ?? '9';
      final minute = match.group(2)?.isEmpty == true ? '00' : (match.group(2) ?? '00');
      final period = match.group(3)?.toUpperCase() ?? 'AM';
      return '$hour:$minute $period';
    }
    return timePart;
  }
  
  Future<void> _loadVendorData() async {
    setState(() => _isLoadingVendors = true);
    
    try {
      // Load approved vendor applications for the current market if editing
      if (_isEditing) {
        _approvedApplications = await VendorApplicationService.getApprovedApplicationsForMarket(widget.market!.id);
      }
      
      // Load existing managed vendors for the current market if editing
      if (_isEditing) {
        _existingManagedVendors = await ManagedVendorService.getVendorsForMarketAsync(widget.market!.id);
      }
    } catch (e) {
      debugPrint('Error loading vendor data: $e');
    } finally {
      setState(() => _isLoadingVendors = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlace == null) {
      UIUtils.showErrorSnackBar(context, 'Please select a location for the market');
      return;
    }
    if (_marketSchedules.isEmpty) {
      UIUtils.showErrorSnackBar(context, 'Please configure at least one market schedule');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        // Update existing market
        await _updateMarketWithSchedules();
      } else {
        // Create new market
        await _createMarketWithSchedules();
      }
    } catch (e) {
      if (mounted) {
        UIUtils.showErrorSnackBar(context, 'Error ${_isEditing ? 'updating' : 'creating'} market: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _createMarketWithSchedules() async {
    // Parse address components from selected place
    final addressComponents = _parseAddressComponents(_selectedPlace!.formattedAddress);
    
    // First create the market
    final market = Market(
      id: '',
      name: _nameController.text.trim(),
      address: addressComponents['address'] ?? _selectedPlace!.formattedAddress,
      city: addressComponents['city'] ?? '',
      state: addressComponents['state'] ?? '',
      latitude: _selectedPlace!.latitude,
      longitude: _selectedPlace!.longitude,
      operatingDays: _generateLegacyOperatingDays(), // Keep for backward compatibility
      description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : null,
      associatedVendorIds: _selectedVendorIds,
      createdAt: DateTime.now(),
    );

    final createdMarketId = await MarketService.createMarket(market);
    
    // Then create the schedules and link them to the market
    final scheduleIds = <String>[];
    for (final schedule in _marketSchedules) {
      final scheduleWithMarketId = schedule.copyWith(marketId: createdMarketId);
      final scheduleId = await MarketService.createMarketSchedule(scheduleWithMarketId);
      scheduleIds.add(scheduleId);
    }
    
    // Update the market with schedule IDs
    final updatedMarket = market.copyWith(
      id: createdMarketId,
      scheduleIds: scheduleIds,
    );
    await MarketService.updateMarket(createdMarketId, updatedMarket.toFirestore());
    
    if (mounted) {
      Navigator.pop(context, updatedMarket);
    }
  }
  
  Future<void> _updateMarketWithSchedules() async {
    final market = widget.market!;
    
    // Parse address components from selected place
    final addressComponents = _parseAddressComponents(_selectedPlace!.formattedAddress);
    
    // Update market basic info
    final updatedMarket = market.copyWith(
      name: _nameController.text.trim(),
      address: addressComponents['address'] ?? _selectedPlace!.formattedAddress,
      city: addressComponents['city'] ?? market.city,
      state: addressComponents['state'] ?? market.state,
      latitude: _selectedPlace!.latitude,
      longitude: _selectedPlace!.longitude,
      description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim() 
          : null,
      associatedVendorIds: _selectedVendorIds,
      operatingDays: _generateLegacyOperatingDays(), // Keep for backward compatibility
    );
    
    // TODO: Handle schedule updates properly
    // For now, we'll just update the market info
    await MarketService.updateMarket(market.id, updatedMarket.toFirestore());
    
    if (mounted) {
      Navigator.pop(context, updatedMarket);
    }
  }
  
  Map<String, String> _generateLegacyOperatingDays() {
    final operatingDays = <String, String>{};
    
    for (final schedule in _marketSchedules) {
      if (schedule.type == ScheduleType.recurring && schedule.daysOfWeek != null) {
        for (final dayIndex in schedule.daysOfWeek!) {
          final dayName = _getDayNameFromIndex(dayIndex);
          if (dayName != null) {
            operatingDays[dayName.toLowerCase()] = '${schedule.startTime}-${schedule.endTime}';
          }
        }
      }
    }
    
    return operatingDays;
  }
  
  String? _getDayNameFromIndex(int dayIndex) {
    switch (dayIndex) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return null;
    }
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


  Widget _buildVendorManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Associate Vendors',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select approved vendors and managed vendors to associate with this market',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoadingVendors)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          // Approved vendor applications
          if (_approvedApplications.isNotEmpty) ...[
            Text(
              'Approved Vendor Applications',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...(_approvedApplications.map((application) => _buildVendorApplicationTile(application))),
            const SizedBox(height: 16),
          ],
          // Existing managed vendors
          if (_existingManagedVendors.isNotEmpty) ...[
            Text(
              'Managed Vendors',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...(_existingManagedVendors.map((vendor) => _buildManagedVendorTile(vendor))),
            const SizedBox(height: 16),
          ],
          // Create new vendor button
          OutlinedButton.icon(
            onPressed: () => _showCreateVendorDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create New Vendor'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.teal,
              side: BorderSide(color: Colors.teal),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVendorApplicationTile(VendorApplication application) {
    final isSelected = _selectedVendorIds.contains(application.vendorId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedVendorIds.add(application.vendorId);
            } else {
              _selectedVendorIds.remove(application.vendorId);
            }
          });
        },
        title: Text(application.vendorBusinessName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact: ${application.vendorDisplayName}'),
            if (application.vendorCategories.isNotEmpty)
              Text('Categories: ${application.vendorCategories.join(', ')}'),
          ],
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Text(
            'APPROVED',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagedVendorTile(ManagedVendor vendor) {
    final isSelected = _selectedVendorIds.contains(vendor.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            if (value == true) {
              _selectedVendorIds.add(vendor.id);
            } else {
              _selectedVendorIds.remove(vendor.id);
            }
          });
        },
        title: Text(vendor.businessName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact: ${vendor.contactName}'),
            if (vendor.categories.isNotEmpty)
              Text('Categories: ${vendor.categoriesDisplay}'),
          ],
        ),
        secondary: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Text(
            'MANAGED',
            style: TextStyle(
              color: Colors.blue[700],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateVendorDialog() {
    // TODO: Implement vendor creation dialog
    UIUtils.showInfoSnackBar(context, 'Vendor creation dialog not implemented yet');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * AppConstants.dialogWidthRatio,
        height: MediaQuery.of(context).size.height * AppConstants.dialogHeightRatio,
        padding: const EdgeInsets.all(AppConstants.dialogPadding),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.storefront,
                  color: Colors.teal,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isEditing ? 'Edit Market' : 'Create New Market',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Market Name *',
                          prefixIcon: Icon(Icons.storefront),
                          border: OutlineInputBorder(),
                          helperText: 'e.g., "Downtown Farmers Market"',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter the market name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Market Location *',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          LocationSearchWidgets.googlePlaces(
                            initialLocation: _selectedAddress,
                            onPlaceSelected: _onPlaceSelected,
                            onCleared: _onAddressCleared,
                          ),
                          if (_selectedPlace != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green[700], size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Location selected: ${_selectedPlace!.formattedAddress}',
                                      style: TextStyle(
                                        color: Colors.green[700],
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description (Optional)',
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                          helperText: 'Brief description of your market',
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: 24),
                      // Market Schedule Form
                      MarketScheduleForm(
                        initialSchedules: _marketSchedules,
                        onSchedulesChanged: (schedules) {
                          setState(() {
                            _marketSchedules = schedules;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      // Vendor Management Section
                      _buildVendorManagementSection(),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEditing ? 'Update Market' : 'Create Market'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}