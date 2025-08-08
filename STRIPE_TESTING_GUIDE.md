# 🧪 Stripe Subscription Testing Guide

## 🔧 Recent Bug Fixes (January 8, 2025)

### Fixed Issues:
- ✅ **Route Error:** Added missing `/premium/upgrade` route to app router (fixes crash when clicking upgrade buttons)
- ✅ **Price Inconsistency:** Standardized shopper premium to **$4.00/month** across all screens (was $4.99 in some places)
- ✅ **Premium UI Logic:** Fixed premium detection with dual-check system (checks both subscription service AND user profile `isPremium` flag)
- ✅ **UI Overflow:** Fixed TierSpecificDashboard 525px overflow in upgrade prompt section
- ✅ **State Management:** Added app lifecycle observer to refresh premium UI when returning from Stripe payment

### Testing the Fixes:
1. **Route Fix Test:** Click any "Upgrade" button → should navigate smoothly (no more route errors)
2. **Price Consistency Test:** Check all upgrade screens show **$4.00/month** for shopper premium
3. **Premium UI Test:** Complete payment → return to app → premium features should appear immediately 
4. **Overflow Fix Test:** View upgrade prompts on any screen size → should scroll properly without overflow

### What Was Fixed:
1. **Missing Route:** Users clicking upgrade buttons no longer crash - added `/premium/upgrade` route
2. **Price Consistency:** All shopper premium pricing now shows $4.00 (was $4.99 in some places, $4 in others)
3. **Premium Detection:** App now checks both `SubscriptionService.hasFeature()` AND `UserProfile.isPremium` field
4. **UI Updates:** Premium features now appear immediately after successful payment completion
5. **Layout Issues:** Upgrade prompt section no longer overflows on smaller screens

## Quick Testing Steps

### 1. Test Button (Easiest)
1. Navigate to `/organizer/subscription-test` in debug mode
2. Click "🧪 Test: Mark User as Premium" button
3. Check browser console for detailed debug logs
4. Verify user gets marked as premium

### 2. Real Stripe Test (Full Flow)
1. Navigate to `/organizer/subscription-test` in debug mode  
2. Click "Upgrade Now" for any subscription tier
3. Use Stripe test card: `4242 4242 4242 4242`
4. Enter any future expiry (e.g., `12/34`) and CVC (e.g., `123`)
5. Complete checkout in browser
6. **Important**: After successful payment, you'll be redirected to the app
7. Check browser console for comprehensive debug logs

## What Debug Logs to Look For

### 🔍 Console Output Flow
```
💳 ========= STRIPE CHECKOUT LAUNCH =========
🚀 Starting checkout for shopper subscription
👤 User ID: [your-user-id]
📧 User email: [your-email]
⏰ Timestamp: [timestamp]
💰 Price ID: [stripe-price-id]
🔍 Environment check:
   STRIPE_SECRET_KEY present: true/false
   STRIPE_PUBLISHABLE_KEY present: true/false
🔄 Creating Stripe checkout session...
✅ Checkout URL created: [stripe-checkout-url]
🌐 Launching checkout in browser...
✅ Checkout launched successfully!
```

### 🎯 After Successful Payment
```
🔄 ========= SUBSCRIPTION SUCCESS ROUTE HIT =========
🌐 Full URL: hipop://subscription/success?session_id=...&user_id=...
🔍 Query parameters: {session_id: cs_..., user_id: ...}
📋 Session ID: cs_test_...
👤 User ID: [your-user-id]
⏰ Timestamp: [timestamp]

🎯 ========= SUBSCRIPTION SUCCESS CALLBACK =========
🎯 Processing subscription success for user: [user-id]
🔍 Verifying Stripe session: [session-id]
⏰ Timestamp: [timestamp]

🔐 Processing REAL Stripe session - verifying with Stripe API
🌐 Making API call to Stripe...
🔐 Starting Stripe session verification...
✅ Stripe secret key found (length: [key-length])
🌐 Making request to: https://api.stripe.com/v1/checkout/sessions/[session-id]
📡 Stripe API Response Status: 200
📦 Response body length: [response-size]
✅ Successfully parsed Stripe response
✅ Stripe session data received
📊 Session data keys: [id, object, payment_status, ...]
💳 Payment status: paid

📝 ========= USER PROFILE PREMIUM UPGRADE =========
👤 User ID: [user-id]
🏪 Stripe Customer ID: cus_...
📋 Stripe Subscription ID: sub_...
💰 Stripe Price ID: price_...
🔍 Loading existing user profile...
✅ User profile loaded Successfully
📊 Current profile status:
   isPremium: false
   subscriptionStatus: free
   userType: shopper
🔄 Creating upgraded profile...
💾 Saving to Firestore database...
✅ User [user-id] upgraded to premium successfully!
🎉 New profile status:
   isPremium: true
   subscriptionStatus: active
```

## Debug Environment Variables

Make sure your `.env` file has:
```env
STRIPE_SECRET_KEY=sk_test_...
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_PRICE_SHOPPER_PREMIUM=price_...
STRIPE_PRICE_VENDOR_PREMIUM=price_...  
STRIPE_PRICE_MARKET_ORGANIZER_PREMIUM=price_...
```

## Common Issues & Solutions

### ❌ "STRIPE_SECRET_KEY not found in environment"
- Check your `.env` file exists and has the correct key
- Restart the app after adding environment variables

### ❌ "User profile not found"
- Make sure you're logged in as a valid user
- Check Firestore for the user profile document

### ❌ "Stripe API Error: 404"
- The session ID might be invalid or expired
- Try creating a new checkout session

### ❌ No debug logs appearing
- Make sure you're running in debug mode
- Check browser developer console (F12)
- Logs appear in the Flutter debug console

## Testing Checklist

- [ ] Environment variables loaded correctly
- [ ] Stripe checkout launches successfully  
- [ ] Test payment completes in Stripe
- [ ] Success URL redirects back to app
- [ ] Session verification works with Stripe API
- [ ] User profile gets updated to premium
- [ ] All debug logs show successful flow
- [ ] User can access premium features

## 🔄 Testing the Bug Fixes

### Test Premium UI Updates:
1. Sign in as a shopper
2. Complete Stripe payment for premium subscription
3. ✅ Verify shopper home shows premium features (not upgrade prompts)
4. ✅ Check that premium feed enhancements appear
5. ✅ Confirm vendor following features are accessible

### Test Price Consistency:
1. Navigate through different premium upgrade screens
2. ✅ Verify all shopper premium pricing shows "$4.00/month" or "$4/month"
3. ✅ Check TierSpecificDashboard, shopper home, premium feed enhancements

### Test Route Fix:
1. Navigate to premium dashboard (when on free tier)
2. Click any "Upgrade to [Tier]" button
3. ✅ Verify no route crash occurs
4. ✅ Should navigate to premium onboarding screen

### Test UI Overflow Fix:
1. Navigate to premium dashboard on free tier
2. View upgrade prompt with multiple tier cards
3. ✅ Verify no 525px overflow on smaller screens
4. ✅ Confirm content scrolls properly

## Next Steps After Testing

1. ✅ Verify premium features work for upgraded users
2. 🔄 Test subscription cancellation flow
3. 🚀 Set up webhooks for production security
4. 📊 Add subscription management UI
5. 🔐 Switch to production Stripe keys when ready

---
**Note**: This is a staging environment with comprehensive debug logging. Remove debug prints before production deployment.