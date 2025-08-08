import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';
import 'package:hipop/features/market/models/market.dart';
import 'package:hipop/features/shared/models/user_profile.dart';
import 'package:hipop/features/vendor/services/vendor_application_service.dart';
import 'package:hipop/features/market/services/market_service.dart';
import 'package:hipop/features/shared/services/user_profile_service.dart';
import 'package:hipop/features/shared/widgets/date_selection_calendar.dart';
import 'package:go_router/go_router.dart';

class VendorApplicationForm extends StatefulWidget {
  final String marketId;
  final Market? market;

  const VendorApplicationForm({
    super.key,
    required this.marketId,
    this.market,
  });

  @override
  State<VendorApplicationForm> createState() => _VendorApplicationFormState();
}

class _VendorApplicationFormState extends State<VendorApplicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _specialMessageController = TextEditingController();
  final _howDidYouHearController = TextEditingController();
  
  bool _isLoading = false;
  bool _hasApplied = false;
  Market? _market;
  UserProfile? _vendorProfile;
  bool _loadingData = true;
  
  // Date selection
  List<DateTime> _selectedDates = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _specialMessageController.dispose();
    _howDidYouHearController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    
    try {
      // Load market data
      if (widget.market != null) {
        _market = widget.market;
      } else {
        _market = await MarketService.getMarket(widget.marketId);
      }

      // Load vendor profile
      if (mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated) {
          _vendorProfile = await UserProfileService().getUserProfile(authState.user.uid);
          await _checkIfAlreadyApplied();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _checkIfAlreadyApplied() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && _market != null) {
      try {
        final hasApplied = await VendorApplicationService.hasVendorApplied(
          authState.user.uid,
          _market!.id,
        );
        setState(() => _hasApplied = hasApplied);
      } catch (e) {
        // Ignore error, assume not applied
      }
    }
  }

  Future<void> _submitApplication() async {
    // Check if at least one date is selected
    if (_selectedDates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) {
        throw Exception('User not authenticated');
      }

      // Submit application using the new date-based approach
      await VendorApplicationService.submitApplicationWithDates(
        authState.user.uid,
        _market!.id,
        _selectedDates,
        specialMessage: _specialMessageController.text.trim().isEmpty 
            ? null 
            : _specialMessageController.text.trim(),
        howDidYouHear: _howDidYouHearController.text.trim().isEmpty 
            ? null 
            : _howDidYouHearController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply to Market'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _loadingData 
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_market == null) {
      return const Center(
        child: Text('Market not found'),
      );
    }

    // Check if user is a vendor
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated && authState.userType != 'vendor') {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.store_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Vendor Account Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Only vendor accounts can apply to markets. Please switch to a vendor account or create one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/auth'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Account'),
            ),
          ],
        ),
      );
    }

    if (_vendorProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Please complete your vendor profile first',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'You need a complete profile to apply to markets',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/vendor/profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      );
    }

    if (!_vendorProfile!.isProfileComplete) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Profile Incomplete',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please complete your vendor profile before applying to markets',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/vendor/profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Complete Profile'),
            ),
          ],
        ),
      );
    }

    if (_hasApplied) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 64, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Already Applied',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'You have already applied to ${_market!.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/vendor/applications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('View Application Status'),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.orange.shade50,
            Colors.white,
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildMarketInfo(),
              const SizedBox(height: 24),
              _buildProfilePreview(),
              const SizedBox(height: 24),
              _buildDateSelection(),
              const SizedBox(height: 24),
              _buildSpecialMessageField(),
              const SizedBox(height: 24),
              _buildHowDidYouHearField(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarketInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _market!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_market!.address}, ${_market!.city}, ${_market!.state}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Your Vendor Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/vendor/profile'),
                  child: const Text('Edit'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProfileField('Business Name', _vendorProfile!.businessName),
            _buildProfileField('Contact', _vendorProfile!.displayName),
            _buildProfileField('Email', _vendorProfile!.email),
            if (_vendorProfile!.phoneNumber?.isNotEmpty == true)
              _buildProfileField('Phone', _vendorProfile!.phoneNumber),
            if (_vendorProfile!.bio?.isNotEmpty == true)
              _buildProfileField('Description', _vendorProfile!.bio),
            if (_vendorProfile!.categories.isNotEmpty)
              _buildProfileField('Categories', _vendorProfile!.categories.join(', ')),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Select Dates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the specific dates you want to operate at this market:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DateSelectionCalendar(
              initialSelectedDates: _selectedDates,
              onDatesChanged: (List<DateTime> selectedDates) {
                setState(() {
                  _selectedDates = selectedDates;
                });
              },
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              title: 'Select your operating dates',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecialMessageField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.message, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Special Message (Optional)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Any special requests or message for the market organizer:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _specialMessageController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Special equipment needs, booth preferences, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHowDidYouHearField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.teal),
                const SizedBox(width: 8),
                const Text(
                  'How did you hear about this market?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Help us understand how vendors discover our markets:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _howDidYouHearController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Social media, word of mouth, website, etc.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitApplication,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
            : const Text(
                'Submit Application',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}