import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hipop/core/theme/hipop_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/market.dart';
import '../../premium/services/subscription_service.dart';

/// Enhanced Market Form Section for Vendor Recruitment
/// Provides a clean, conversion-optimized interface for market organizers
/// to configure vendor recruitment settings
class MarketVendorRecruitmentForm extends StatefulWidget {
  final Market? market;
  final bool isLookingForVendors;
  final Function(Map<String, dynamic>) onRecruitmentDataChanged;
  
  const MarketVendorRecruitmentForm({
    super.key,
    this.market,
    required this.isLookingForVendors,
    required this.onRecruitmentDataChanged,
  });
  
  @override
  State<MarketVendorRecruitmentForm> createState() => _MarketVendorRecruitmentFormState();
}

class _MarketVendorRecruitmentFormState extends State<MarketVendorRecruitmentForm>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  // Form controllers
  final _applicationUrlController = TextEditingController();
  final _applicationFeeController = TextEditingController();
  final _dailyBoothFeeController = TextEditingController();
  final _vendorSpotsController = TextEditingController();
  final _vendorRequirementsController = TextEditingController();
  
  // Form state
  bool _isLookingForVendors = false;
  DateTime? _applicationDeadline;
  bool _hasPremiumAccess = false;
  bool _isCheckingPremium = true;
  
  // Validation
  String? _urlError;
  String? _spotsError;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _initializeFormData();
    _checkPremiumAccess();
  }
  
  void _initializeFormData() {
    final market = widget.market;
    _isLookingForVendors = widget.isLookingForVendors;
    
    if (market != null) {
      _applicationUrlController.text = market.applicationUrl ?? '';
      _applicationFeeController.text = market.applicationFee?.toString() ?? '';
      _dailyBoothFeeController.text = market.dailyBoothFee?.toString() ?? '';
      _vendorSpotsController.text = market.vendorSpotsTotal?.toString() ?? '';
      _vendorRequirementsController.text = market.vendorRequirements ?? '';
      _applicationDeadline = market.applicationDeadline;
    }
    
    if (_isLookingForVendors) {
      _animationController.forward();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _applicationUrlController.dispose();
    _applicationFeeController.dispose();
    _dailyBoothFeeController.dispose();
    _vendorSpotsController.dispose();
    _vendorRequirementsController.dispose();
    super.dispose();
  }
  
  Future<void> _checkPremiumAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final hasAccess = await SubscriptionService.hasFeature(user.uid, 'vendor_post_creation');
        setState(() {
          _hasPremiumAccess = hasAccess;
          _isCheckingPremium = false;
        });
      } catch (e) {
        setState(() {
          _hasPremiumAccess = false;
          _isCheckingPremium = false;
        });
      }
    } else {
      setState(() {
        _hasPremiumAccess = false;
        _isCheckingPremium = false;
      });
    }
  }
  
  void _toggleRecruitment(bool value) {
    // Check if user has premium access
    if (value && !_hasPremiumAccess) {
      _showPremiumDialog();
      return;
    }
    
    setState(() {
      _isLookingForVendors = value;
      if (value) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    _notifyDataChanged();
  }
  
  void _showPremiumDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: HiPopColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.diamond,
              color: HiPopColors.premiumGold,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Premium Feature',
                style: TextStyle(
                  color: HiPopColors.darkTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"Looking for Vendors" posts are a premium feature that helps you:',
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            _buildBenefit('Appear in vendor discovery feeds'),
            _buildBenefit('Get matched with qualified vendors'),
            _buildBenefit('Receive direct vendor applications'),
            _buildBenefit('Track vendor responses'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: HiPopColors.premiumGold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: HiPopColors.premiumGold.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.star,
                    color: HiPopColors.premiumGold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade to Market Organizer Pro for \$69/month',
                      style: TextStyle(
                        color: HiPopColors.darkTextPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
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
              'Maybe Later',
              style: TextStyle(color: HiPopColors.darkTextSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                context.go('/premium/upgrade?tier=marketOrganizerPro&userId=${user.uid}');
              }
            },
            icon: const Icon(Icons.diamond, size: 18),
            label: const Text('Upgrade Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: HiPopColors.premiumGold,
              foregroundColor: HiPopColors.darkBackground,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: HiPopColors.successGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: HiPopColors.darkTextSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _notifyDataChanged() {
    final data = {
      'isLookingForVendors': _isLookingForVendors,
      'applicationUrl': _applicationUrlController.text.trim(),
      'applicationFee': double.tryParse(_applicationFeeController.text),
      'dailyBoothFee': double.tryParse(_dailyBoothFeeController.text),
      'vendorSpotsTotal': int.tryParse(_vendorSpotsController.text),
      'vendorSpotsAvailable': int.tryParse(_vendorSpotsController.text), // Initially same as total
      'applicationDeadline': _applicationDeadline,
      'vendorRequirements': _vendorRequirementsController.text.trim(),
    };
    widget.onRecruitmentDataChanged(data);
  }
  
  bool _validateUrl(String url) {
    if (url.isEmpty) return true; // Optional field
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }
  
  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(days: 1));
    final lastDate = now.add(const Duration(days: 365));
    
    final picked = await showDatePicker(
      context: context,
      initialDate: _applicationDeadline ?? firstDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: HiPopColors.primaryDeepSage,
              onPrimary: HiPopColors.darkTextPrimary,
              surface: HiPopColors.darkSurface,
              onSurface: HiPopColors.darkTextPrimary,
              surfaceContainerHighest: HiPopColors.darkSurfaceVariant,
              onSurfaceVariant: HiPopColors.darkTextSecondary,
              secondary: HiPopColors.accentMauve,
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
              todayForegroundColor: WidgetStateProperty.all(HiPopColors.primaryDeepSage),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return HiPopColors.primaryDeepSage;
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
                  return HiPopColors.primaryDeepSage;
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
                foregroundColor: HiPopColors.primaryDeepSage,
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
    
    if (picked != null) {
      setState(() {
        _applicationDeadline = picked;
      });
      _notifyDataChanged();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle Section with Enhanced Design
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: HiPopColors.darkSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isLookingForVendors 
                  ? HiPopColors.accentMauve 
                  : HiPopColors.darkBorder,
              width: _isLookingForVendors ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isLookingForVendors
                          ? HiPopColors.primaryDeepSage
                          : HiPopColors.lightTextDisabled,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.storefront,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                fontWeight: FontWeight.bold,
                                color: HiPopColors.darkTextPrimary,
                              ),
                            ),
                            if (!_hasPremiumAccess) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _showPremiumDialog,
                                icon: Icon(
                                  Icons.diamond,
                                  color: HiPopColors.premiumGold,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Premium Feature',
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _hasPremiumAccess 
                            ? 'Enable vendor recruitment for this market'
                            : 'Premium feature - Upgrade to enable',
                          style: TextStyle(
                            fontSize: 12,
                            color: _hasPremiumAccess 
                              ? HiPopColors.darkTextSecondary
                              : HiPopColors.warningAmber,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isLookingForVendors,
                    onChanged: _hasPremiumAccess ? _toggleRecruitment : (value) => _showPremiumDialog(),
                    activeColor: HiPopColors.primaryDeepSage,
                    inactiveThumbColor: _hasPremiumAccess ? null : HiPopColors.darkTextTertiary,
                    inactiveTrackColor: _hasPremiumAccess ? null : HiPopColors.darkBorder,
                  ),
                ],
              ),
              
              // Animated Info Banner
              SizeTransition(
                sizeFactor: _expandAnimation,
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: HiPopColors.darkBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: HiPopColors.infoBlueGray,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your market will appear in vendor discovery feeds when enabled',
                          style: TextStyle(
                            fontSize: 12,
                            color: HiPopColors.darkTextSecondary,
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
        
        // Animated Form Fields
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Application URL Field
                _buildFormField(
                  label: 'Application URL',
                  hint: 'https://yourmarket.com/vendor-application',
                  controller: _applicationUrlController,
                  icon: Icons.link,
                  isRequired: true,
                  errorText: _urlError,
                  onChanged: (value) {
                    setState(() {
                      _urlError = _validateUrl(value) 
                          ? null 
                          : 'Please enter a valid URL';
                    });
                    _notifyDataChanged();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Vendor Spots Field
                _buildFormField(
                  label: 'Number of Vendor Spots',
                  hint: 'Total spots available',
                  controller: _vendorSpotsController,
                  icon: Icons.groups,
                  isRequired: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: _spotsError,
                  onChanged: (value) {
                    setState(() {
                      final spots = int.tryParse(value);
                      _spotsError = (spots == null || spots <= 0)
                          ? 'Please enter a valid number'
                          : null;
                    });
                    _notifyDataChanged();
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Fee Fields Row
                Row(
                  children: [
                    Expanded(
                      child: _buildFormField(
                        label: 'Application Fee',
                        hint: '\$0.00',
                        controller: _applicationFeeController,
                        icon: Icons.attach_money,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _notifyDataChanged(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFormField(
                        label: 'Daily Booth Fee',
                        hint: '\$0.00',
                        controller: _dailyBoothFeeController,
                        icon: Icons.payments,
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        onChanged: (_) => _notifyDataChanged(),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Application Deadline
                _buildDateField(),
                
                const SizedBox(height: 16),
                
                // Vendor Requirements
                _buildFormField(
                  label: 'Vendor Requirements',
                  hint: 'List any specific requirements for vendors...',
                  controller: _vendorRequirementsController,
                  icon: Icons.checklist,
                  maxLines: 3,
                  onChanged: (_) => _notifyDataChanged(),
                ),
                
                // Visual Feedback Section
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: HiPopColors.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: HiPopColors.successGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 20,
                            color: HiPopColors.successGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Visibility Benefits',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: HiPopColors.darkTextPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...[
                        'Featured in vendor discovery searches',
                        'Priority placement for urgent deadlines',
                        'Direct vendor applications through the platform',
                        'Automatic spot availability tracking',
                      ].map((benefit) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: HiPopColors.successGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                benefit,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HiPopColors.darkTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isRequired = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: HiPopColors.darkTextTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
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
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          onChanged: onChanged,
          style: TextStyle(
            color: HiPopColors.darkTextPrimary,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: HiPopColors.darkTextTertiary,
              fontSize: 14,
            ),
            errorText: errorText,
            errorStyle: TextStyle(
              color: HiPopColors.errorPlum,
              fontSize: 12,
            ),
            filled: true,
            fillColor: HiPopColors.darkSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: HiPopColors.darkBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: HiPopColors.accentMauve,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: HiPopColors.errorPlum,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: HiPopColors.darkTextTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Application Deadline',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: HiPopColors.darkTextPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _selectDeadline,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: HiPopColors.darkSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: HiPopColors.darkBorder),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _applicationDeadline != null
                        ? '${_applicationDeadline!.month}/${_applicationDeadline!.day}/${_applicationDeadline!.year}'
                        : 'Select deadline date',
                    style: TextStyle(
                      color: _applicationDeadline != null
                          ? HiPopColors.darkTextPrimary
                          : HiPopColors.darkTextTertiary,
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: HiPopColors.darkTextTertiary,
                ),
              ],
            ),
          ),
        ),
        if (_applicationDeadline != null) ...[
          const SizedBox(height: 4),
          Text(
            _getDeadlineHelperText(),
            style: TextStyle(
              fontSize: 12,
              color: _isDeadlineUrgent() 
                  ? HiPopColors.warningAmber 
                  : HiPopColors.darkTextTertiary,
            ),
          ),
        ],
      ],
    );
  }
  
  String _getDeadlineHelperText() {
    if (_applicationDeadline == null) return '';
    
    final daysUntil = _applicationDeadline!.difference(DateTime.now()).inDays;
    
    if (daysUntil <= 3) {
      return 'Urgent: Only $daysUntil days until deadline';
    } else if (daysUntil <= 7) {
      return 'Applications close in $daysUntil days';
    } else {
      return 'Applications open for ${daysUntil} days';
    }
  }
  
  bool _isDeadlineUrgent() {
    if (_applicationDeadline == null) return false;
    final daysUntil = _applicationDeadline!.difference(DateTime.now()).inDays;
    return daysUntil <= 3;
  }
}