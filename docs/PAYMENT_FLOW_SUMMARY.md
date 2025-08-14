# HiPOP Payment Flow Summary

## Overview
This document describes the payment flow for all user types across all platforms.

## Payment Routes

All user types access premium upgrades through the same route:
- **Route**: `/premium/upgrade`
- **Parameters**: `tier` (vendor/marketOrganizer/shopper) and `userId`

### Entry Points

#### Vendor
- `vendor_application_form.dart:828` → `/premium/upgrade?tier=vendor&userId=${authState.user.uid}`
- `vendor_market_discovery_screen.dart:484` → `/premium/upgrade?tier=vendor&userId=${user.uid}`
- `vendor_market_discovery_screen.dart:1722` → `/premium/upgrade?tier=vendor&userId=${user.uid}`

#### Market Organizer
- Various screens → `/premium/upgrade?tier=marketOrganizerPro&userId=${userId}`

#### Shopper
- Various screens → `/premium/upgrade?tier=shopperPro&userId=${userId}`

## Payment Implementation by Platform

### Web Platform
**Detection**: `kIsWeb == true`

**Flow**:
1. User clicks "Continue to Secure Checkout" button
2. `StripeService.launchSubscriptionCheckout()` is called
3. Firebase Cloud Function creates Stripe Checkout session
4. Browser redirects to Stripe's hosted checkout page
5. User completes payment on Stripe's secure page
6. User is redirected back to success/cancel URL
7. Webhook processes subscription activation

**UI Elements**:
- Blue informational box explaining web payment
- "Continue to Secure Checkout" button with lock icon
- Loading spinner while redirecting
- Error message display if redirect fails

### iOS/Android Platforms
**Detection**: `kIsWeb == false`

**Flow**:
1. Native `CardField` widget displays in-app
2. User enters card details directly
3. Payment processed via Stripe SDK
4. Real-time validation and completion
5. Direct confirmation without leaving app

**UI Elements**:
- Native Stripe CardField widget
- In-line card validation
- "Subscribe Now" button
- Real-time error messages

## File Structure

### Core Files
- **Payment Form**: `lib/features/premium/widgets/stripe_payment_form.dart`
  - Platform detection logic
  - Web redirect handler
  - Native CardField implementation

- **Stripe Service**: `lib/features/premium/services/stripe_service.dart`
  - Checkout session creation
  - URL launching
  - Subscription verification

- **Premium Onboarding**: `lib/features/premium/screens/premium_onboarding_screen.dart`
  - Tier selection
  - Payment form integration
  - Success/failure handling

- **Cloud Functions**: `functions/src/index.ts`
  - `createCheckoutSession` - Creates Stripe sessions
  - `stripeWebhook` - Processes webhooks
  - `verifySubscriptionSession` - Validates payments

## Pricing

### Subscription Tiers
- **Vendor Pro**: $29.00/month
- **Market Organizer Pro**: $69.00/month  
- **Shopper Premium**: $4.00/month

### Price IDs (Environment Variables)
- `STRIPE_PRICE_VENDOR_PREMIUM`
- `STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM`
- `STRIPE_PRICE_SHOPPER_PREMIUM`

## Security Features

1. **Web Payments**:
   - All processing on Stripe's PCI-compliant servers
   - Secure redirect with session tokens
   - Webhook validation with signing secrets

2. **Mobile Payments**:
   - Native Stripe SDK integration
   - Tokenized card data
   - No raw card data stored

## Testing

### Web Testing
1. Navigate to any premium upgrade button
2. Should see "Web Payment" box with redirect button
3. Click "Continue to Secure Checkout"
4. Redirects to Stripe Checkout
5. Complete payment
6. Returns to success page

### Mobile Testing
1. Navigate to any premium upgrade button
2. Should see native card input field
3. Enter test card: 4242 4242 4242 4242
4. Complete in-app payment
5. Success dialog appears

## Error Handling

### Common Issues
1. **Platform._operatingSystem error on web**: Fixed by conditional CardField rendering
2. **Redirect failures**: Handled with try-catch and user-friendly messages
3. **Payment failures**: Clear error messages with retry options

## Deployment URLs

- **Staging**: https://hipop-markets-staging.web.app
- **Production**: https://hipop-app.web.app

## Notes

- All user types (vendor, organizer, shopper) use the same payment infrastructure
- Web always uses Stripe Checkout redirect
- Mobile always uses native Stripe SDK
- Platform detection is handled automatically via `kIsWeb`