# Stripe Flutter SDK Setup Guide for HiPOP

## ✅ Configuration Status

This document outlines the Stripe Flutter SDK requirements and confirms our implementation status.

## Platform Requirements

### Android ✅

- [x] **Min SDK 21** - Set in `android/app/build.gradle.kts`
- [x] **FlutterFragmentActivity** - Updated in `MainActivity.kt`
- [x] **AppCompat Theme** - Updated in `styles.xml` and `styles-night.xml`
- [x] **ProGuard Rules** - Added in `android/app/proguard-rules.pro`
- [x] **R8 Full Mode Disabled** - Set in `android/gradle.properties`
- [x] **Kotlin 1.8.0+** - Using latest Kotlin version

### iOS ✅

- [x] **iOS 13.0+** - Set to iOS 14.0 in `ios/Podfile`
- [x] **Camera Permission** - Added to `Info.plist` for card scanning
- [x] **Merchant Identifier** - Configured in `main.dart`

### Web Support ✅

- [x] **flutter_stripe_web** - Added to dependencies
- [x] **Publishable Key** - Configured in environment

## Implementation Features

### Payment Methods Supported
- ✅ Credit/Debit Cards
- ✅ Apple Pay (iOS)
- ✅ Google Pay (Android)
- ✅ 3D Secure Authentication

### UI Components Used
- ✅ CardField - For card input
- ✅ Custom payment form
- ✅ Error handling and validation

## Environment Variables

Configure these in your `.env` file:

```env
# Stripe Configuration
STRIPE_PUBLISHABLE_KEY=pk_test_xxx  # Your Stripe publishable key
STRIPE_SECRET_KEY=sk_test_xxx       # Your Stripe secret key (server-side only)
STRIPE_WEBHOOK_SECRET=whsec_xxx     # Webhook endpoint secret

# Price IDs for Subscriptions
STRIPE_PRICE_VENDOR_PRO=price_xxx
STRIPE_PRICE_MARKET_ORGANIZER_PRO=price_xxx
STRIPE_PRICE_SHOPPER_PREMIUM=price_xxx
```

## Security Considerations

### PCI Compliance ✅
- Card details are sent directly to Stripe
- No sensitive payment data stored locally
- Using Stripe's tokenization

### Data Protection ✅
- Input validation on all fields
- SQL/XSS injection prevention
- Secure error handling

## Testing

### Test Cards
Use these test card numbers for development:

- **Success**: 4242 4242 4242 4242
- **Requires Authentication**: 4000 0025 0000 3155
- **Declined**: 4000 0000 0000 9995

### Test Mode
The app uses test keys in staging/development. Switch to live keys for production.

## Deployment Checklist

### Before App Store Submission
- [ ] Switch to live Stripe keys
- [ ] Test with real cards in production mode
- [ ] Verify Apple Pay configuration
- [ ] Update webhook endpoints

### Before Google Play Submission
- [ ] Switch to live Stripe keys
- [ ] Test with real cards in production mode
- [ ] Verify Google Pay configuration
- [ ] Enable ProGuard for release builds

## Important Notes

### App Store Guidelines
Per Apple and Google guidelines, if you're selling digital products or services within your app (subscriptions, in-game currencies, premium content), you must use the app store's in-app purchase APIs.

HiPOP uses Stripe for marketplace transactions (vendor fees, market organizer subscriptions) which are allowed as they're for physical goods and services.

### Build Requirements
After making Android configuration changes:
1. Clean build: `flutter clean`
2. Get packages: `flutter pub get`
3. Rebuild: `flutter build apk` or `flutter run`

## Troubleshooting

### Android Issues
- **Theme crashes**: Ensure AppCompat theme is used
- **Build failures**: Check minSdk is 21 or higher
- **R8 crashes**: Verify `android.enableR8.fullMode=false`

### iOS Issues
- **Build errors**: Run `cd ios && pod install`
- **Payment sheet not showing**: Check iOS deployment target

### Web Issues
- **Stripe not defined**: Ensure flutter_stripe_web is imported
- **CORS errors**: Configure server for proper headers

## Support Resources

- [Stripe Flutter SDK Docs](https://docs.page/flutter-stripe/flutter_stripe)
- [Stripe Dashboard](https://dashboard.stripe.com)
- [Flutter Stripe Examples](https://github.com/flutter-stripe/flutter_stripe/tree/main/example)

## Implementation Status

✅ **COMPLETE** - All Stripe SDK requirements have been implemented and configured for Android, iOS, and Web platforms.