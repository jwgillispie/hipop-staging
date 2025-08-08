import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/event.dart';
import '../../../shared/services/event_service.dart';
import '../../../market/models/market.dart';

class EditEventScreen extends StatefulWidget {
  final Event event;
  
  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _tagsController;
  
  // Form state
  late DateTime _startDateTime;
  late DateTime _endDateTime;
  Market? _selectedMarket;
  List<Market> _availableMarkets = [];
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadMarkets();
  }

  void _initializeForm() {
    _nameController = TextEditingController(text: widget.event.name);
    _descriptionController = TextEditingController(text: widget.event.description);
    _addressController = TextEditingController(text: widget.event.address);
    _cityController = TextEditingController(text: widget.event.city);
    _stateController = TextEditingController(text: widget.event.state);
    _tagsController = TextEditingController(text: widget.event.tags.join(', '));
    
    _startDateTime = widget.event.startDateTime;
    _endDateTime = widget.event.endDateTime;
    _latitude = widget.event.latitude;
    _longitude = widget.event.longitude;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadMarkets() async {
    // For now, we'll skip market loading since the association isn't implemented
    // This can be added later when market-organizer association is implemented
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDateTime : _endDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStartDate ? _startDateTime : _endDateTime),
      );
      
      if (pickedTime != null) {
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

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _addressController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'startDateTime': _startDateTime,
        'endDateTime': _endDateTime,
        'marketId': _selectedMarket?.id,
        'tags': _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        'updatedAt': DateTime.now(),
      };

      await EventService.updateEvent(widget.event.id, updatedData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating event: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Event'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _updateEvent,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Event Name *',
                  hintText: 'Enter event name',
                  prefixIcon: Icon(Icons.event),
                  border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe your event',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Date and Time Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Schedule',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Start Date/Time
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Start Date & Time'),
                        subtitle: Text(DateFormat('MMM d, yyyy - h:mm a').format(_startDateTime)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _selectDateTime(context, true),
                      ),
                      const Divider(),
                      
                      // End Date/Time
                      ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('End Date & Time'),
                        subtitle: Text(DateFormat('MMM d, yyyy - h:mm a').format(_endDateTime)),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _selectDateTime(context, false),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Address
                      TextFormField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                          hintText: 'Enter event address',
                          prefixIcon: Icon(Icons.location_on),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // City and State
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _cityController,
                              decoration: const InputDecoration(
                                labelText: 'City *',
                                hintText: 'City',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'City is required';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _stateController,
                              decoration: const InputDecoration(
                                labelText: 'State *',
                                hintText: 'State',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'State is required';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Market Association
              if (_availableMarkets.isNotEmpty) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Market Association',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Market>(
                          value: _selectedMarket,
                          decoration: const InputDecoration(
                            labelText: 'Associate with Market (Optional)',
                            prefixIcon: Icon(Icons.store),
                            border: OutlineInputBorder(),
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
                decoration: const InputDecoration(
                  labelText: 'Tags (Optional)',
                  hintText: 'Enter tags separated by commas',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                  helperText: 'Example: festival, food, community',
                ),
              ),
              const SizedBox(height: 24),

              // Update Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : const Text(
                          'Update Event',
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