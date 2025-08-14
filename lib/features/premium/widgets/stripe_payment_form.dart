import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
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
  bool _cardComplete = false;
  final TextEditingController _couponController = TextEditingController();
  String? _appliedCoupon;
  bool _couponValidated = false;
  
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

  Future<void> _handlePayment() async {
    if (_isProcessing || !_cardComplete) {
      debugPrint('⚠️ Payment blocked - processing: $_isProcessing, card complete: $_cardComplete');
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      debugPrint('💳 Starting payment process...');
      // Step 1: Create payment intent on the server
      final clientSecret = await PaymentService.createPaymentIntent(
        userId: widget.userId,
        priceId: widget.priceId,
        userType: widget.userType,
        customerEmail: widget.userEmail,
      );

      // Step 2: Confirm payment with Stripe
      final paymentIntent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              email: widget.userEmail,
            ),
          ),
        ),
      );

      // Check payment status
      if (paymentIntent.status != PaymentIntentsStatus.Succeeded) {
        throw Exception('Payment was not successful: ${paymentIntent.status}');
      }

      // Step 3: If we get here, payment was successful
      // The cloud function webhook will handle subscription creation
      widget.onSuccess();
    } on StripeException catch (e) {
      setState(() {
        _errorMessage = _getStripeErrorMessage(e);
        _isProcessing = false;
      });
      widget.onError(_errorMessage!);
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

  String _getStripeErrorMessage(StripeException e) {
    // Check the actual failure code enum
    if (e.error.code == FailureCode.Failed) {
      return e.error.message ?? 'Payment failed. Please try again';
    } else if (e.error.code == FailureCode.Canceled) {
      return 'Payment was canceled';
    } else if (e.error.code == FailureCode.Timeout) {
      return 'Payment timed out. Please try again';
    }
    
    // Check for declined card reasons
    if (e.error.declineCode != null) {
      switch (e.error.declineCode) {
        case 'insufficient_funds':
          return 'Insufficient funds';
        case 'lost_card':
        case 'stolen_card':
          return 'This card has been reported lost or stolen';
        case 'expired_card':
          return 'Your card has expired';
        case 'incorrect_cvc':
          return 'Incorrect security code';
        case 'card_declined':
        default:
          return e.error.message ?? 'Your card was declined';
      }
    }
    
    return e.error.message ?? 'Payment failed. Please try again';
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
              Text(
                _getPriceDisplay(),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Coupon code input field
        _buildCouponField(),
        
        const SizedBox(height: 16),
        
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
            onPressed: (_isProcessing || !_cardComplete) ? null : _handlePayment,
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
        Text(
          'By subscribing, you agree to our Terms of Service and Privacy Policy',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCardInputField() {
    // For web, we need to handle CardField differently to avoid Platform._operatingSystem error
    if (kIsWeb) {
      // On web, use a simpler approach or Stripe's web-specific implementation
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          children: [
            // Use Stripe's web card element or fallback UI
            _buildWebCardInput(),
          ],
        ),
      );
    } else {
      // On mobile platforms, use the standard CardField
      return CardField(
        enablePostalCode: true,
        onCardChanged: (card) {
          setState(() {
            _errorMessage = null;
            _cardComplete = card?.complete ?? false;
          });
        },
        decoration: InputDecoration(
          labelText: 'Card Details',
          hintText: 'Enter your card information',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      );
    }
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
              child: TextField(
                controller: _couponController,
                enabled: !_couponValidated,
                decoration: InputDecoration(
                  hintText: 'Enter coupon code',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(
                    Icons.local_offer,
                    color: _couponValidated ? Colors.green : Colors.grey,
                  ),
                  suffixIcon: _couponValidated
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  filled: true,
                  fillColor: _couponValidated
                      ? Colors.green.shade50
                      : Colors.white,
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  // Convert to uppercase
                  _couponController.value = _couponController.value.copyWith(
                    text: value.toUpperCase(),
                    selection: TextSelection.collapsed(
                      offset: value.length,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _couponValidated
                  ? _removeCoupon
                  : (_couponController.text.isEmpty || _isProcessing)
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
                backgroundColor: _couponValidated ? Colors.red : null,
              ),
              child: Text(
                _couponValidated ? 'Remove' : 'Apply',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        if (_couponValidated) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Coupon "$_appliedCoupon" applied successfully!',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
  
  void _validateCoupon() {
    final couponCode = _couponController.text.trim().toUpperCase();
    if (couponCode.isEmpty) return;
    
    setState(() {
      _appliedCoupon = couponCode;
      _couponValidated = true;
      _errorMessage = null;
    });
    
    debugPrint('🎟️ Coupon applied: $couponCode');
  }
  
  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponValidated = false;
      _couponController.clear();
    });
    
    debugPrint('🎟️ Coupon removed');
  }
}