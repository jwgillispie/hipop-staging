import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/payment_service.dart';
import '../services/premium_error_handler.dart';
import '../services/stripe_service.dart';

class StripePaymentForm extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String userType;
  final String priceId;
  final String tier;
  final VoidCallback onSuccess;
  final Function(String) onError;

  const StripePaymentForm({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.userType,
    required this.priceId,
    required this.tier,
    required this.onSuccess,
    required this.onError,
  });

  @override
  State<StripePaymentForm> createState() => _StripePaymentFormState();
}

class _StripePaymentFormState extends State<StripePaymentForm> {
  bool _isProcessing = false;
  String? _errorMessage;
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCoupon;
  bool _couponValidated = false;
  bool _validatingCoupon = false;
  PromoCodeValidation? _promoValidation;
  double? _discountedPrice;
  
  @override
  void initState() {
    super.initState();
    _initializePayment();
  }
  
  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        // Use the centralized PaymentService initialization
        await PaymentService.initialize();
        debugPrint('✅ Payment system initialized successfully');
        
        // Clear any previous error messages on success
        if (mounted) {
          setState(() {
            _errorMessage = null;
          });
        }
        return;
      } catch (e) {
        retryCount++;
        debugPrint('❌ Failed to initialize payment system (attempt $retryCount/$maxRetries): $e');
        
        // Handle specific web-related errors
        String errorMessage = _getInitializationErrorMessage(e);
        
        // If this is the last retry attempt, show the error
        if (retryCount >= maxRetries) {
          if (mounted) {
            setState(() {
              _errorMessage = errorMessage;
            });
          }
          break;
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  String _getInitializationErrorMessage(dynamic error) {
    final errorString = error.toString();
    
    // Handle Platform._operatingSystem errors
    if (errorString.contains('Platform._operatingSystem') || 
        errorString.contains('Unsupported operation')) {
      return kIsWeb 
        ? 'Web payment initialization failed. Please refresh the page or ensure JavaScript is enabled.'
        : 'Platform detection error. Please try restarting the app.';
    }
    
    // Handle Stripe-specific errors
    if (errorString.contains('publishable key')) {
      return 'Payment configuration error. Please contact support.';
    }
    
    if (errorString.contains('merchant identifier')) {
      return kIsWeb 
        ? 'Payment system loaded with limited features on web.'
        : 'Apple Pay configuration issue - card payments still available.';
    }
    
    // Generic error message
    return kIsWeb 
      ? 'Payment system initialization failed. Please refresh the page and try again.'
      : 'Failed to initialize payment system. Please restart the app and try again.';
  }

  Future<void> _handleMobilePayment() async {
    if (_isProcessing) {
      debugPrint('⚠️ Payment blocked - already processing');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('📱 Starting Payment Sheet flow...');
      
      // Use the Payment Sheet flow from PaymentService
      await PaymentService.processPaymentWithSheet(
        priceId: widget.priceId,
        customerEmail: widget.userEmail,
        userId: widget.userId,
        userType: widget.userType,
        promoCode: _appliedCoupon,
        merchantDisplayName: 'HiPop',
      );

      // If we get here, payment was successful
      debugPrint('✅ Payment Sheet completed successfully');
      widget.onSuccess();
    } on PaymentException catch (e) {
      debugPrint('❌ Payment error: ${e.message}');
      setState(() {
        _errorMessage = e.message;
        _isProcessing = false;
      });
      widget.onError(e.message);
    } on PremiumError catch (e) {
      setState(() {
        _errorMessage = e.userMessage;
        _isProcessing = false;
      });
      widget.onError(e.userMessage);
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error in payment: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _isProcessing = false;
      });
      
      // Ensure we always call onError to maintain proper state
      try {
        widget.onError(_errorMessage!);
      } catch (callbackError) {
        debugPrint('❌ Error in onError callback: $callbackError');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Payment amount display
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Text(
                'Subscription: ${widget.tier}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  if (_promoValidation != null && _promoValidation!.isValid) ...[
                    Text(
                      _getPriceDisplay(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getDiscountedPriceDisplay(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ] else ...[
                    Text(
                      _getPriceDisplay(),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Coupon code input field - only show on mobile
        if (!kIsWeb) ...[
          _buildCouponField(),
          const SizedBox(height: 16),
        ],
        
        // Card input field - web-safe implementation
        _buildCardInputField(),
        
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 24),
        
        // Security badges
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              'Secure payment powered by Stripe',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        
        // Submit button - only show on mobile platforms
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isProcessing ? null : _handleMobilePayment,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Subscribe Now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Terms and conditions
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            Text(
              'By subscribing, you agree to our ',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            GestureDetector(
              onTap: () => _showTermsDialog(context),
              child: Text(
                'Terms of Service',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ', ',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            GestureDetector(
              onTap: () => _showPrivacyDialog(context),
              child: Text(
                'Privacy Policy',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ', and ',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            GestureDetector(
              onTap: () => _showPaymentTermsDialog(context),
              child: Text(
                'Payment Terms',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCardInputField() {
    if (kIsWeb) {
      // On web, use redirect to Stripe Checkout
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: _buildWebCardInput(),
      );
    } else {
      // On mobile platforms, use Payment Sheet (no card input needed)
      return _buildMobilePaymentInfo();
    }
  }

  Widget _buildMobilePaymentInfo() {
    // For mobile, show Payment Sheet info instead of card input
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Secure Payment',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your payment will be processed securely using Stripe\'s native payment system. You can pay with any card, Apple Pay, or Google Pay.',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPaymentMethodIcon(Icons.credit_card, 'Cards'),
              _buildPaymentMethodIcon(Icons.apple, 'Apple Pay'),
              _buildPaymentMethodIcon(Icons.android, 'Google Pay'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Icon(icon, size: 24, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildWebCardInput() {
    // For web, use Stripe Payment Sheet or redirect to Stripe Checkout
    // CardField is not supported on web due to Platform._operatingSystem access
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Web Payment',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Click below to proceed to Stripe\'s secure checkout page. You\'ll be redirected to complete your payment.',
            style: TextStyle(
              color: Colors.blue.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _handleWebPayment,
            icon: _isProcessing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.lock_outline),
            label: Text(_isProcessing ? 'Redirecting to Stripe...' : 'Continue to Secure Checkout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              minimumSize: const Size(250, 48),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleWebPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Use the existing StripeService to create and launch checkout session
      debugPrint('🌐 Launching Stripe Checkout for web payment...');
      
      // Launch Stripe Checkout using the existing service
      // The StripeService handles the tier mapping internally
      await StripeService.launchSubscriptionCheckout(
        userId: widget.userId,
        userEmail: widget.userEmail,
        userType: widget.userType,
        couponCode: _appliedCoupon,
        context: context,
      );
      
      // The user will be redirected to Stripe Checkout
      // After payment, they'll be redirected back to the success URL
      // The StripeService will handle the redirect and subscription verification
      
      // Keep the processing state true since we're redirecting
      // The user will leave this page anyway
      debugPrint('✅ Stripe Checkout redirect initiated');
      
    } catch (e) {
      debugPrint('❌ Web payment error: $e');
      setState(() {
        _errorMessage = 'Failed to launch payment page: ${e.toString()}';
        _isProcessing = false;
      });
    }
  }

  String _getPriceDisplay() {
    // Map user types to display prices
    // Using the same pricing as defined in PaymentService
    switch (widget.userType) {
      case 'vendor':
        return '\$29.00/month';
      case 'market_organizer':
        return '\$69.00/month';
      case 'shopper':
        return '\$4.00/month';
      default:
        // Fallback to price ID mapping if user type doesn't match
        final priceMap = {
          'price_vendorPro_monthly': '\$29.00/month',
          'price_marketOrganizerPro_monthly': '\$69.00/month',
          'price_shopperPro_monthly': '\$4.00/month',
        };
        return priceMap[widget.priceId] ?? '\$0.00/month';
    }
  }
  
  Widget _buildCouponField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Have a promo code?',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _couponController,
                enabled: !_couponValidated && !_validatingCoupon,
                style: const TextStyle(
                  color: Color(0xFF040000), // HiPop black color
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(
                    Icons.local_offer,
                    color: _couponValidated ? Colors.green : Colors.grey,
                  ),
                  suffixIcon: _validatingCoupon
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _couponValidated
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : null,
                  filled: true,
                  fillColor: _couponValidated
                      ? Colors.green.shade50
                      : Colors.white,
                ),
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  // Custom formatter to handle iOS text visibility issues
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    // Ensure text is always uppercase and properly formatted
                    final upperText = newValue.text.toUpperCase();
                    return TextEditingValue(
                      text: upperText,
                      selection: TextSelection.collapsed(offset: upperText.length),
                    );
                  }),
                ],
                onChanged: (value) {
                  // Reset validation state when user types
                  if (_couponValidated) {
                    setState(() {
                      _couponValidated = false;
                      _appliedCoupon = null;
                      _promoValidation = null;
                      _discountedPrice = null;
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _validatingCoupon
                  ? null
                  : _couponValidated
                      ? _removeCoupon
                      : _isProcessing
                          ? null
                          : _validateCoupon,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor: _couponValidated 
                    ? Colors.red 
                    : _couponController.text.trim().isEmpty
                        ? Colors.grey.shade400 // Disabled gray state when empty
                        : Colors.green, // Enabled green state
                foregroundColor: Colors.white,
              ),
              child: _validatingCoupon
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _couponValidated ? 'Remove' : 'Apply',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
        if (_couponValidated && _promoValidation != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Coupon Applied ✓',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_promoValidation!.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _promoValidation!.description!,
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'You save ${_getSavingsText()}',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  Future<void> _validateCoupon() async {
    final couponCode = _couponController.text.trim().toUpperCase();
    if (couponCode.isEmpty) {
      // Show a message to user that they need to enter a code
      setState(() {
        _errorMessage = 'Please enter a coupon code';
      });
      return;
    }
    
    setState(() {
      _validatingCoupon = true;
      _errorMessage = null;
    });
    
    try {
      debugPrint('🎟️ Validating coupon with backend: $couponCode');
      
      // Call the backend validation service
      final validation = await PaymentService.validatePromoCode(couponCode);
      
      setState(() {
        _validatingCoupon = false;
        
        if (validation.isValid) {
          _appliedCoupon = couponCode;
          _couponValidated = true;
          _promoValidation = validation;
          _discountedPrice = _calculateDiscountedPrice(validation);
          debugPrint('✅ Coupon validated successfully: $couponCode');
        } else {
          _errorMessage = validation.errorMessage ?? 'Invalid coupon code';
          debugPrint('❌ Coupon validation failed: ${validation.errorMessage}');
        }
      });
    } catch (e) {
      debugPrint('❌ Error validating coupon: $e');
      setState(() {
        _validatingCoupon = false;
        _errorMessage = 'Unable to validate coupon. Please try again.';
      });
    }
  }
  
  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponValidated = false;
      _promoValidation = null;
      _discountedPrice = null;
      _couponController.clear();
    });
    
    debugPrint('🎟️ Coupon removed');
  }
  
  double _calculateDiscountedPrice(PromoCodeValidation validation) {
    final originalPrice = _getOriginalPrice();
    
    // Validate original price is not NaN or invalid
    if (originalPrice.isNaN || originalPrice.isInfinite || originalPrice <= 0) {
      debugPrint('❌ Invalid original price: $originalPrice, using fallback');
      return _getOriginalPrice(); // Use fallback logic
    }
    
    if (validation.discountAmount != null) {
      final discountAmount = validation.discountAmount!;
      // Ensure discount amount is valid
      if (discountAmount.isNaN || discountAmount.isInfinite || discountAmount < 0) {
        debugPrint('❌ Invalid discount amount: $discountAmount, ignoring discount');
        return originalPrice;
      }
      return (originalPrice - discountAmount).clamp(0.0, originalPrice);
    }
    
    if (validation.discountPercent != null) {
      final discountPercent = validation.discountPercent!;
      // Ensure discount percent is valid
      if (discountPercent.isNaN || discountPercent.isInfinite || discountPercent < 0 || discountPercent > 100) {
        debugPrint('❌ Invalid discount percent: $discountPercent, ignoring discount');
        return originalPrice;
      }
      final discount = originalPrice * (discountPercent / 100);
      // Ensure calculated discount is valid
      if (discount.isNaN || discount.isInfinite) {
        debugPrint('❌ Invalid calculated discount: $discount, ignoring discount');
        return originalPrice;
      }
      return (originalPrice - discount).clamp(0.0, originalPrice);
    }
    
    return originalPrice;
  }
  
  double _getOriginalPrice() {
    // Map user types to prices (in dollars)
    switch (widget.userType) {
      case 'vendor':
        return 29.00;
      case 'market_organizer':
        return 69.00;
      case 'shopper':
        return 4.00;
      default:
        return 0.00;
    }
  }
  
  String _getDiscountedPriceDisplay() {
    if (_discountedPrice != null) {
      // Ensure discounted price is not NaN or invalid before displaying
      if (_discountedPrice!.isNaN || _discountedPrice!.isInfinite || _discountedPrice! < 0) {
        debugPrint('❌ Invalid discounted price for display: $_discountedPrice, using original price');
        return _getPriceDisplay();
      }
      return '\$${_discountedPrice!.toStringAsFixed(2)}/month';
    }
    return _getPriceDisplay();
  }
  
  String _getSavingsText() {
    if (_promoValidation == null || !_promoValidation!.isValid) {
      return '';
    }
    
    final originalPrice = _getOriginalPrice();
    
    if (_promoValidation!.discountAmount != null) {
      final discountAmount = _promoValidation!.discountAmount!;
      // Validate discount amount before displaying
      if (discountAmount.isNaN || discountAmount.isInfinite || discountAmount < 0) {
        debugPrint('❌ Invalid discount amount for display: $discountAmount');
        return '';
      }
      return '\$${discountAmount.toStringAsFixed(2)}';
    }
    
    if (_promoValidation!.discountPercent != null) {
      final discountPercent = _promoValidation!.discountPercent!;
      // Validate discount percent before calculating
      if (discountPercent.isNaN || discountPercent.isInfinite || discountPercent < 0 || discountPercent > 100) {
        debugPrint('❌ Invalid discount percent for display: $discountPercent');
        return '';
      }
      final savings = originalPrice * (discountPercent / 100);
      // Validate calculated savings
      if (savings.isNaN || savings.isInfinite || savings < 0) {
        debugPrint('❌ Invalid calculated savings for display: $savings');
        return '';
      }
      return '\$${savings.toStringAsFixed(2)} (${discountPercent.toStringAsFixed(0)}% off)';
    }
    
    return '';
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Text(
            '''HiPop Markets Terms of Service

ABOUT HIPOP MARKETS
HiPop is a comprehensive three-sided marketplace platform that connects vendors, shoppers, and market organizers in the local pop-up market ecosystem.

SUBSCRIPTION SERVICES
• Shopper Premium: \$4/month - Enhanced discovery and notifications
• Vendor Premium: \$29/month - Advanced analytics and priority placement  
• Market Organizer Premium: \$69/month - Comprehensive management tools

PAYMENT PROCESSING
• All payments processed securely through Stripe
• Automatic recurring billing on subscription date
• Payment methods: Cards, Apple Pay, Google Pay
• Secure tokenization and PCI compliance

By subscribing, you agree to our complete Terms of Service, Privacy Policy, and Payment Terms available in the Legal Documents section.''',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/legal');
            },
            child: const Text('View Full Terms'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            '''HiPop Markets Privacy Policy

DATA COLLECTION
We collect account information, usage analytics, and payment data to provide our three-sided marketplace services.

ANALYTICS USAGE
• Performance metrics and user engagement data
• Market discovery and vendor interaction analytics
• Payment processing and subscription management data

THIRD-PARTY SERVICES
• Stripe for secure payment processing
• Google Cloud Platform for data storage
• Firebase for authentication and real-time features

Your privacy is protected with enterprise-grade security. View our complete Privacy Policy in Legal Documents for full details on data collection, usage, and your rights.''',
            style: TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/legal');
            },
            child: const Text('View Full Policy'),
          ),
        ],
      ),
    );
  }

  void _showPaymentTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Terms'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Subscription: ${widget.tier}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Price: ${_getPriceDisplay()}',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                '''PAYMENT TERMS
• Automatic recurring monthly billing
• Secure processing through Stripe
• Cancel anytime in app settings
• No refunds for partial usage
• Prorated charges for plan changes

PAYMENT SECURITY
• End-to-end encryption
• PCI DSS compliance
• Tokenized payment storage
• Fraud protection systems

View complete Payment Terms in Legal Documents for full billing policies, refund procedures, and security details.''',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/legal');
            },
            child: const Text('View Full Terms'),
          ),
        ],
      ),
    );
  }
}