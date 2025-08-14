import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/payment_service.dart';
import '../services/premium_error_handler.dart';

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
  
  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  Future<void> _initializePayment() async {
    try {
      // Use the centralized PaymentService initialization
      await PaymentService.initialize();
      debugPrint('✅ Payment system initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize payment system: $e');
      
      // Handle specific web-related errors
      String errorMessage = 'Failed to initialize payment system. Please try again.';
      if (e.toString().contains('Platform._operatingSystem') || 
          e.toString().contains('Unsupported operation')) {
        errorMessage = kIsWeb 
          ? 'Initializing payment system for web. Please ensure JavaScript is enabled.'
          : 'Platform compatibility issue. Please try again.';
      }
      if (mounted) {
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    }
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
        
        // Card input field
        CardField(
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
        ),
        
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
        
        const SizedBox(height: 16),
        
        // Submit button
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

  String _getPriceDisplay() {
    // Map price IDs to display prices
    // In production, this should come from Stripe or your backend
    final priceMap = {
      'price_vendorPro_monthly': '\$29.00/month',
      'price_marketOrganizerPro_monthly': '\$69.00/month',
      'price_shopperPro_monthly': '\$4.00/month',
    };
    
    return priceMap[widget.priceId] ?? '\$0.00/month';
  }
}